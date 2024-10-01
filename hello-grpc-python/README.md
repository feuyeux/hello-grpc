# grpc python demo

## 1 Setup

```sh
# 1. Aliyun's mirror of the Python Package Index (PyPI)
pip config set global.index-url https://mirrors.aliyun.com/pypi/simple
# 2. Tsinghua University's mirror of PyPI
pip config set global.index-url https://pypi.tuna.tsinghua.edu.cn/simple
# 3. University of Science and Technology of China's mirror of PyPI
pip config set global.index-url https://pypi.mirrors.ustc.edu.cn/simple
```

```sh
sh init.sh
```

```sh
(
#generate requirements.txt with dependencies
pip install pipreqs
pipreqs --encoding utf-8 . --force
)
```

## 2 Generate

```bash
conda activate grpc_env
sh proto2py.sh
```

## 3 Run

```bash
conda activate grpc_env
sh server_start.sh
```

```bash
conda activate grpc_env
sh client_start.sh
```

### UT

```sh
conda activate grpc_env
python -m unittest tests/test_utils.py
```
