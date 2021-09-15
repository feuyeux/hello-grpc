import { GrpcServer } from "https://deno.land/x/grpc_basic@0.4.3/server.ts";
import { Landing } from "./landing.d.ts";
const port = 15070;
const server = new GrpcServer();

const protoPath = new URL("proto/landing.proto", import.meta.url);
const protoFile = await Deno.readTextFile(protoPath);

server.addService<Landing>(protoFile, {

    async Talk({ data,meta }) {
        const message = `hello ${data || meta}`;
        return { message };
    },

});

console.log(`gonna listen on ${port} port`);
for await (const conn of Deno.listen({ port })) {
    server.handle(conn);
}