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
    const response = await fetch(new URL(path, this.baseUrl), {
      method,
      signal: AbortSignal.timeout(5_000),
    });
    if (!response.ok)
      throw new Error(`Media service returned HTTP ${String(response.status)}`);
    return (await response.json()) as CameraControlResponse;
  }
}
