import {
    sendUnaryData,
    Server,
    ServerCredentials,
    ServerUnaryCall,
} from "@grpc/grpc-js";
import { UserManagerService } from "../codegen/protos/user_grpc_pb";
import { UserRequest, UserResponse, User } from "../codegen/protos/user_pb";

// 実際には DB のような永続層から取得するはず
const users = new Map([
    [1, { id: 1, name: "Alice", isAdmin: true }],
    [2, { id: 2, name: "Bob", isAdmin: false }],
    [3, { id: 3, name: "Carol", isAdmin: false }],
]);

function get(
    call: ServerUnaryCall<UserRequest, UserResponse>,
    callback: sendUnaryData<UserResponse>
) {
    const requestId = call.request.getId();
    const targetedUser = users.get(requestId);

    const response = new UserResponse();
    if (!targetedUser) {
        throw new Error("User is not found.");
    }

    const user = new User();
    user.setId(targetedUser.id);
    user.setName(targetedUser.name);
    user.setIsAdmin(targetedUser.isAdmin);

    response.setUser(user);
    callback(null, response);
}

function startServer() {
    const server = new Server();
    server.addService(UserManagerService, { get });
    server.bindAsync(
        "0.0.0.0:50051",
        ServerCredentials.createInsecure(),
        (error, port) => {
            if (error) {
                console.error(error);
            }
            server.start();
            console.log(`server start listing on port ${port}`);
        }
    );
}

startServer();