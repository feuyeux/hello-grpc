## grpc python demo
### 1 Setup
```bash
python -m pip install virtualenv
virtualenv venv
source venv/bin/activate
python -m pip install --upgrade pip

python -m pip install grpcio
pip install grpcio-tools
```

### 2 Generate
```bash
sh proto2py.sh
```

### 3 Run
```bash
sh start_server.sh
```

```bash
sh start_client.sh
```