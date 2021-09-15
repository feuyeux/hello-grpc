import {getClient} from "https://deno.land/x/grpc_basic@0.4.3/client.ts";
import {Landing} from "./landing.d.ts";

const protoPath = new URL("proto/landing.proto", import.meta.url);
const protoFile = await Deno.readTextFile(protoPath);

const client = getClient<Landing>({
    port: 15070,
    root: protoFile,
    serviceName: "Landing",
});

/* unary calls */
console.log(await client.Talk({data: "unary #1", meta: "unary #2"}));

/* server stream */
for await (const reply of client.ShoutHello({name: "streamed"})) {
    console.log(reply);
}

client.close();