## grpc python demo
### 1 Setup
```bash
pip config set global.index-url https://mirrors.aliyun.com/pypi/simple
pip config set global.index-url https://pypi.tuna.tsinghua.edu.cn/simple
pip config set global.index-url https://pypi.mirrors.ustc.edu.cn/simple
```
python2
```bash
python -m pip install --upgrade pip
pip install virtualenv

which virtualenv
/Library/Frameworks/Python.framework/Versions/2.7/bin/virtualenv
```
python3
```bash
python3 -m pip install --upgrade pip
export PATH="/Users/han/Library/Python/3.8/bin:$PATH"
pip3 install virtualenv

which virtualenv
/Users/han/Library/Python/3.8/bin/virtualenv
```

```bash
virtualenv venv
/Users/han/Library/Python/3.8/bin/virtualenv venv

source venv/bin/activate
python -m pip install --upgrade pip

(
#generate requirements.txt with dependencies
pip install pipreqs
pipreqs --encoding utf-8 . --force
)

# https://pypi.org/project/grpcio-tools/
# https://pypi.org/project/protobuf/
# https://pypi.org/project/futures/
#  enum34-1.1.10 futures-3.3.0 grpcio-1.41.1 grpcio-tools-1.41.1 protobuf-3.18.0 six-1.16.0
pip install -r requirements.txt

(python -m pip install grpcio)
```

### 2 Generate
```bash
sh proto2py.sh
```

### 3 Run
```bash
sh server_start.sh
```

```bash
sh client_start.sh
```