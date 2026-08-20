// import type { CameraView } from "../modules/cameras/repository.js";

// declare module "fastify" {
//   interface FastifyInstance {
//     media: MediaClient;
//   }
// }

// export type CameraState =
//   | "disabled"
//   | "starting"
//   | "connecting"
//   | "online"
//   | "degraded"
//   | "reconnecting"
//   | "offline"
//   | "stopping"
//   | "error";

// export interface CameraControlResponse {
//   camera_id: string;
//   state: CameraState;
// }

// export class MediaClientError extends Error {
//   public constructor(
//     public readonly kind:
//       | "unavailable"
//       | "timeout"
//       | "not_found"
//       | "conflict"
//       | "invalid"
//       | "internal",
//     message: string,
//   ) {
//     super(message);
//   }
// }

// export class MediaClient {
//   public constructor(private readonly baseUrl: string) {}

//   public async start(
//     camera: Pick<CameraView, "id">,
//   ): Promise<CameraControlResponse> {
//     return this.request(
//       `/internal/v1/cameras/${encodeURIComponent(camera.id)}/start`,
//       "POST",
//     );
//   }

//   public async stop(cameraId: string): Promise<CameraControlResponse> {
//     return this.request(
//       `/internal/v1/cameras/${encodeURIComponent(cameraId)}/stop`,
//       "POST",
//     );
//   }

//   public async status(cameraId: string): Promise<CameraControlResponse> {
//     return this.request(
//       `/internal/v1/cameras/${encodeURIComponent(cameraId)}/status`,
//       "GET",
//     );
//   }

//   private async request(
//     path: string,
//     method: "GET" | "POST",
//   ): Promise<CameraControlResponse> {
//     let response: Response;
//     try {
//       response = await fetch(new URL(path, this.baseUrl), {
//         method,
//         signal: AbortSignal.timeout(5_000),
//       });
//     } catch (error) {
//       const timeout =
//         error instanceof Error &&
//         (error.name === "TimeoutError" || error.name === "AbortError");
//       throw new MediaClientError(
//         timeout ? "timeout" : "unavailable",
//         timeout ? "Media request timed out" : "Media service is unavailable",
//       );
//     }
//     type MediaErrorKind = "not_found" | "conflict" | "invalid" | "internal";

//     const STATUS_TO_KIND: Record<number, MediaErrorKind> = {
//       400: "invalid",
//       404: "not_found",
//       409: "conflict",
//     };

//     if (!response.ok) {
//       const kind = STATUS_TO_KIND[response.status] ?? "internal";
//       throw new MediaClientError(
//         kind,
//         `Media operation failed with status ${String(response.status)}`,
//       );
//     }
//     return (await response.json()) as CameraControlResponse;
//   }
// }

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

export type MediaErrorKind =
  | "unavailable"
  | "timeout"
  | "not_found"
  | "conflict"
  | "invalid"
  | "internal"
  | "malformed_response";

export class MediaClientError extends Error {
  public constructor(
    public readonly kind: MediaErrorKind,
    message: string,
    public readonly status?: number,
  ) {
    super(message);
    this.name = "MediaClientError";
  }
}

const HTTP_STATUS_TO_KIND: Record<number, MediaErrorKind> = {
  400: "invalid",
  404: "not_found",
  409: "conflict",
};

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
      const isTimeout =
        error instanceof Error &&
        (error.name === "TimeoutError" || error.name === "AbortError");

      throw new MediaClientError(
        isTimeout ? "timeout" : "unavailable",
        isTimeout ? "Media request timed out" : "Media service is unavailable",
      );
    }

    if (!response.ok) {
      const kind = HTTP_STATUS_TO_KIND[response.status] ?? "internal";
      throw new MediaClientError(
        kind,
        `Media operation failed with status ${String(response.status)}`,
        response.status,
      );
    }

    try {
      return (await response.json()) as CameraControlResponse;
    } catch {
      throw new MediaClientError(
        "malformed_response",
        "Failed to parse media service JSON response",
        response.status,
      );
    }
  }
}