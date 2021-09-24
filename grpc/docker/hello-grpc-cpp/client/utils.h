//
// Created by han on 2021/9/9.
//

#ifndef HELLO_GRPC_CPP_UTILS_H
#define HELLO_GRPC_CPP_UTILS_H

namespace hello {
    class Utils {
    public:
        static int Random(int n);

        static long Now();
    };
}

#endif //HELLO_GRPC_CPP_UTILS_H
