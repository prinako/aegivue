import type { CameraView } from "../modules/cameras/repository.js";

declare module "fastify" {
  interface FastifyInstance {
    media: MediaClient;
  }
}

export type CameraState =
  | "disabled"
  | "starting"
  | "connecting"
  | "online"
  | "degraded"
  | "reconnecting"
  | "offline"
  | "stopping"
  | "error";

export interface CameraControlResponse {
  camera_id: string;
  state: CameraState;
}

export class MediaClientError extends Error {
  public constructor(
    public readonly kind:
      | "unavailable"
      | "timeout"
      | "not_found"
      | "conflict"
      | "invalid"
      | "internal",
    message: string,
  ) {
    super(message);
  }
}

export class MediaClient {
  public constructor(private readonly baseUrl: string) {}

  public async start(
    camera: Pick<CameraView, "id">,
  ): Promise<CameraControlResponse> {
    return this.request(
      `/internal/v1/cameras/${encodeURIComponent(camera.id)}/start`,
      "POST",
    );
  }

  public async stop(cameraId: string): Promise<CameraControlResponse> {
    return this.request(
      `/internal/v1/cameras/${encodeURIComponent(cameraId)}/stop`,
      "POST",
    );
  }

  public async status(cameraId: string): Promise<CameraControlResponse> {
    return this.request(
      `/internal/v1/cameras/${encodeURIComponent(cameraId)}/status`,
      "GET",
    );
  }

  private async request(
    path: string,
    method: "GET" | "POST",
  ): Promise<CameraControlResponse> {
    let response: Response;
    try {
      response = await fetch(new URL(path, this.baseUrl), {
        method,
        signal: AbortSignal.timeout(5_000),
      });
    } catch (error) {
      const timeout =
        error instanceof Error &&
        (error.name === "TimeoutError" || error.name === "AbortError");
      throw new MediaClientError(
        timeout ? "timeout" : "unavailable",
        timeout ? "Media request timed out" : "Media service is unavailable",
      );
    }
    if (!response.ok) {
      const kind =
        response.status === 404
          ? "not_found"
          : response.status === 409
            ? "conflict"
            : response.status === 400
              ? "invalid"
              : "internal";
      throw new MediaClientError(
        kind,
        `Media operation failed with status ${String(response.status)}`,
      );
    }
    return (await response.json()) as CameraControlResponse;
  }
}
