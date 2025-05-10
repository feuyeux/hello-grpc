import { TalkRequest } from "./landing_pb"
import { LinkedList } from "fast-linked-list";
import * as grpc from '@grpc/grpc-js'
import * as fs from 'fs'
import * as path from 'path'

export const hellos: string[] = ["Hello", "Bonjour", "Hola", "こんにちは", "Ciao", "안녕하세요"]
export const ans: Map<string, string> = new Map<string, string>()
ans.set("你好", "非常感谢")
ans.set("Hello", "Thank you very much")
ans.set("Bonjour", "Merci beaucoup")
ans.set("Hola", "Muchas Gracias")
ans.set("こんにちは", "どうも ありがとう ございます")
ans.set("Ciao", "Mille Grazie")
ans.set("안녕하세요", "대단히 감사합니다")

export function randomId(max: number) {
    return Math.floor(Math.random() * Math.floor(max)).toString()
}

export function buildLinkRequests(): TalkRequest[] {
    const requests = new LinkedList<TalkRequest>()
    for (let i = 0; i < 3; i++) {
        let request = new TalkRequest()
        request.setData(randomId(5))
        request.setMeta("TypeScript")
        requests.push(request)
    }
    return requests.toArray()
}

export function getVersion(): string {
    try {
        // Try different approaches to find package.json
        let packagePath;

        // Approach 1: Relative to __dirname (common folder)
        packagePath = path.resolve(__dirname, '../package.json');
        if (fs.existsSync(packagePath)) {
            const packageJson = JSON.parse(fs.readFileSync(packagePath, 'utf8'));
            if (packageJson?.dependencies?.['@grpc/grpc-js']) {
                return `grpc.js-version=${packageJson.dependencies['@grpc/grpc-js']}`;
            }
        }

        // Approach 2: Use process.cwd() (current working directory)
        packagePath = path.resolve(process.cwd(), 'package.json');
        if (fs.existsSync(packagePath)) {
            const packageJson = JSON.parse(fs.readFileSync(packagePath, 'utf8'));
            if (packageJson?.dependencies?.['@grpc/grpc-js']) {
                return `grpc.js-version=${packageJson.dependencies['@grpc/grpc-js']}`;
            }
        }

        // Approach 3: Try absolute path
        packagePath = '/Users/han/coding/hello-grpc/hello-grpc-ts/package.json';
        if (fs.existsSync(packagePath)) {
            const packageJson = JSON.parse(fs.readFileSync(packagePath, 'utf8'));
            if (packageJson?.dependencies?.['@grpc/grpc-js']) {
                return `grpc.js-version=${packageJson.dependencies['@grpc/grpc-js']}`;
            }
        }
    } catch (error) {
        console.error('Error getting gRPC version:', error);
    }

    // Fallback if all approaches fail
    return `grpc.js-version=v1.x`;
}