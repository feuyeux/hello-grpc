## grpc python demo
### 1 Setup
```bash
pip config set global.index-url https://mirrors.aliyun.com/pypi/simple/
python -m pip install virtualenv
```

```bash
virtualenv venv
source venv/bin/activate
python -m pip install --upgrade pip

(pip install pipreqs
pipreqs .)

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