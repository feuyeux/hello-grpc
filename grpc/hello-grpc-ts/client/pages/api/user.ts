import type { NextApiRequest, NextApiResponse } from "next";
import { credentials, ServiceError } from "@grpc/grpc-js";

import { UserManagerClient } from "../../codegen/protos/user_grpc_pb";
import { UserRequest, UserResponse } from "../../codegen/protos/user_pb";

const Request = new UserRequest();
const Client = new UserManagerClient(
    "localhost:50051",
    credentials.createInsecure()
);

export type UserApiResponse =
    | { ok: true; user: UserResponse.AsObject["user"] }
    | { ok: false; error: ServiceError };

export default function handler(
    apiReq: NextApiRequest,
    apiRes: NextApiResponse<UserApiResponse>
) {
    const { id } = JSON.parse(apiReq.body);
    Request.setId(id);
    Client.get(Request, (grpcErr, grpcRes) => {
        if (grpcErr) {
            apiRes.status(500).json({ ok: false, error: grpcErr });
        } else {
            const { user } = grpcRes.toObject();
            apiRes.status(200).json({ ok: true, user });
        }
    });
}