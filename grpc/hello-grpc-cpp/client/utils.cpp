//
// Created by han on 2021/9/9.
//
#include <iostream>
#include <stdlib.h>
#include <time.h>
#include "utils.h"

namespace hello {
    int Utils::Random(int n) {
        int a = 0;
        int b = n;
        return (rand() % (b - a + 1)) + a;
    }

    long Utils::Now(){
        std::chrono::system_clock::time_point now = std::chrono::system_clock::now();
        auto value = now.time_since_epoch().count();
        return value;
    }
}