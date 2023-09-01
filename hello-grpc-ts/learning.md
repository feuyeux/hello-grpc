# [Next.js で始める gRPC 通信](https://numb86-tech.hatenablog.com/entry/2022/02/12/154459)

サーバ・クライアント間の通信を gRPC で行う場合、インターフェイスを定義した共通のファイルから、サーバとクライアント双方のコードを生成することができる。
この記事では、インターフェイスの定義ファイルを作成するところから始めて、gRPC を利用した単純なウェブアプリを作っていく。
gRPC についての概念的な説明などは扱わず、実際に手元で動くウェブアプリを作ることで、gRPC を使った開発についてイメージしやすくなることを意図している。

Next.js では API Routes を使って API サーバを作ることができるが、それを gRPC クライアントとして実装する。
そのため、リクエストの流れは以下のようになる。

```
Frontend == (REST) ==> API Routes == (gRPC) ==> gRPC Server
```

動作確認は Node.js の`v16.13.2`で行っており、利用しているライブラリのバージョンは以下の通り。

- gRPC サーバ
  - @grpc/grpc-js@1.5.5
  - google-protobuf@3.19.4
  - grpc_tools_node_protoc_ts@5.3.2
  - grpc-tools@1.11.2
  - ts-node-dev@1.1.8
  - typescript@4.5.5
- gRPC クライアント
  - @grpc/grpc-js@1.5.5
  - @types/node@17.0.17
  - @types/react@17.0.39
  - eslint-config-next@12.0.10
  - eslint@8.9.0
  - google-protobuf@3.19.4
  - grpc_tools_node_protoc_ts@5.3.2
  - grpc-tools@1.11.2
  - next@12.0.10
  - react-dom@17.0.2
  - react@17.0.2
  - typescript@4.5.5

## proto ファイル

まずは、「proto ファイル」と呼ばれる、インターフェイスを定義したファイルを作成する。

プロジェクトのルートディレクトリに`protos`ディレクトリを作り、そのなかに以下の内容の`user.proto`を作成する。

```proto
syntax = "proto3";

service UserManager {
  rpc get (UserRequest) returns (UserResponse) {}
}

message User {
  uint32 id = 1;
  string name = 2;
  bool is_admin = 3;
}

message UserRequest {
  uint32 id = 1;
}

message UserResponse {
  User user = 1;
}
```

`UserManager`というサービスを定義しており、このサービスは`get`という関数（プロシージャ）を持つ。
`get`はパラメータとして`UserRequest`を受け取り、`UserResponse`を返す。

この proto ファイルからコードを生成して、クライアントやサーバの開発を行っていく。
この記事ではどちらも TypeScript で開発するが、他の言語を使ってもよいし、クライアントとサーバで言語を揃える必要もない。
[gRPC がサポートしている言語](https://grpc.io/docs/languages/)なら、どの言語でも proto ファイルからコードを生成できる。

## gRPC サーバの開発

プロジェクトのルートディレクトリに`server`ディレクトリを作り、そこで gRPC サーバの開発を行う。
まずは開発に必要なライブラリをインストールする。

```sh
$ mkdir server
$ cd server
$ yarn add @grpc/grpc-js google-protobuf
$ yarn add -D grpc-tools grpc_tools_node_protoc_ts
```

次に、`codegen`というディレクトリを作り、proto ファイルをコンパイルしてそこにコードを出力する。

```sh
$ mkdir codegen
$ yarn run grpc_tools_node_protoc --plugin=./node_modules/.bin/protoc-gen-ts --js_out=import_style=commonjs,binary:codegen --grpc_out=grpc_js:codegen --ts_out=grpc_js:codegen -I ../ ../protos/user.proto
```

以下のように 4 つのファイルが生成されていれば成功。

```sh
$ ls -1 codegen/protos
user_grpc_pb.d.ts
user_grpc_pb.js
user_pb.d.ts
user_pb.js
```

ここから実際にコードを書いていくので、TypeScript のセットアップを行う。

```sh
$ yarn add -D typescript
$ yarn run tsc --init
```

次に、`src/index.ts`を作成し、以下のように書く。

```typescript
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
```

先程生成した`user_grpc_pb`や`user_pb`を import し、それを使ってコードを書いている。

最後に、`ts-node-dev`を使ってサーバを起動する。

```sh
$ yarn add -D ts-node-dev
$ yarn run ts-node-dev src/index.ts
```

`server start listing on port 50051`と表示されれば成功。

## gRPC クライアントの開発

クライアント側は Next.js を使うため、プロジェクトのルートディレクトリに戻って以下のコマンドを実行する。

```sh
$ yarn create next-app client --ts
```

この時点で、以下のようなディレクトリ構成になっているはず。

```sh
$ tree ./ -L 2
./
├── client
│   ├── README.md
│   ├── next-env.d.ts
│   ├── next.config.js
│   ├── node_modules
│   ├── package.json
│   ├── pages
│   ├── public
│   ├── styles
│   ├── tsconfig.json
│   └── yarn.lock
├── protos
│   └── user.proto
└── server
    ├── codegen
    ├── node_modules
    ├── package.json
    ├── src
    ├── tsconfig.json
    └── yarn.lock
```

以降は、`client`に移動して Next.js での開発を行う。

まずはサーバのときと同様、gRPC 関連のライブラリのインストールと、proto ファイルのコンパイルを行う。

```sh
$ yarn add @grpc/grpc-js google-protobuf
$ yarn add -D grpc-tools grpc_tools_node_protoc_ts
$ mkdir codegen
$ yarn run grpc_tools_node_protoc --plugin=./node_modules/.bin/protoc-gen-ts --js_out=import_style=commonjs,binary:codegen --grpc_out=grpc_js:codegen --ts_out=grpc_js:codegen -I ../ ../protos/user.proto
```

続いて、以下の内容の`pages/api/user.ts`を作る。これが gRPC クライアントとして機能する。

```typescript
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
```

gRPC サーバと同様、proto ファイルから生成されたコードを使って実装している。

最後に、`pages/index.tsx`を編集して UI を作る。

```typescript
import type { NextPage } from "next";
import { useState, Fragment, ChangeEvent } from "react";

import type { UserApiResponse } from "./api/user";

const App: NextPage = () => {
  const [result, setResult] = useState<string>("");
  const [selectedId, setSelectedId] = useState<number>();

  const handleChange = async (e: ChangeEvent<HTMLInputElement>) => {
    const id = Number(e.currentTarget.value);
    setSelectedId(id);

    const res = await fetch("/api/user", {
      method: "POST",
      body: JSON.stringify({ id }),
    });

    const json: UserApiResponse = await res.json();

    if (json.ok) {
      const { user } = json;
      setResult(JSON.stringify(user));
    } else {
      const { code, details } = json.error;
      setResult(`Error! ${code}: ${details}`);
    }
  };

  return (
    <div>
      {[...Array(3)].map((_, index) => {
        const id = index + 1;
        return (
          <Fragment key={id}>
            <input
              type="radio"
              value={id}
              onChange={handleChange}
              checked={id === selectedId}
            />
            {id}{" "}
          </Fragment>
        );
      })}
      <p>{result}</p>
    </div>
  );
};

export default App;
```

gRPC サーバが起動している状態で`$ yarn run dev`して`http://localhost:3000/`にアクセスすると、選択したチェックボックスに応じて表示が変わる。
例えば`1`を選択すると以下が表示されるはず。

```json
{"id":1,"name":"Alice","isAdmin":true}
```

gRPC サーバが起動していない場合はエラーメッセージが表示される。

```sh
Error! 14: No connection established
```