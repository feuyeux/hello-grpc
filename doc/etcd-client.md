# etcd-

## python

```sh
$ brew install python

Running `brew update --auto-update`...
Warning: python@3.11 3.11.4_1 is already installed and up-to-date.
To reinstall 3.11.4_1, run:
  brew reinstall python@3.11

$ export PATH="/usr/local/opt/python/libexec/bin:$PATH"

$ python -V
Python 3.11.4

$ pip -V
pip 23.2.1 from /usr/local/lib/python3.11/site-packages/pip (python 3.11)

#### https://pypi.org/project/python-etcd/
$ pip install python-etcd
Collecting python-etcd
  Downloading python-etcd-0.4.5.tar.gz (37 kB)
  Preparing metadata (setup.py) ... done
Collecting urllib3>=1.7.1 (from python-etcd)
  Obtaining dependency information for urllib3>=1.7.1 from https://files.pythonhosted.org/packages/9b/81/62fd61001fa4b9d0df6e31d47ff49cfa9de4af03adecf339c7bc30656b37/urllib3-2.0.4-py3-none-any.whl.metadata
  Downloading urllib3-2.0.4-py3-none-any.whl.metadata (6.6 kB)
Collecting dnspython>=1.13.0 (from python-etcd)
  Obtaining dependency information for dnspython>=1.13.0 from https://files.pythonhosted.org/packages/f6/b4/0a9bee52c50f226a3cbfb54263d02bb421c7f2adc136520729c2c689c1e5/dnspython-2.4.2-py3-none-any.whl.metadata
  Downloading dnspython-2.4.2-py3-none-any.whl.metadata (4.9 kB)
Downloading dnspython-2.4.2-py3-none-any.whl (300 kB)
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ 300.4/300.4 kB 539.9 kB/s eta 0:00:00
Downloading urllib3-2.0.4-py3-none-any.whl (123 kB)
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ 123.9/123.9 kB 34.6 kB/s eta 0:00:00
Building wheels for collected packages: python-etcd
  Building wheel for python-etcd (setup.py) ... done
  Created wheel for python-etcd: filename=python_etcd-0.4.5-py3-none-any.whl size=38483 sha256=1d44a6d105ba93a09146e0edb110ace870d54096260482d76c17f40ae3d11375
  Stored in directory: /Users/han/Library/Caches/pip/wheels/f9/78/df/7c075842d2ac19c8b9ea2e822deeb748ca8ec0372f2c3bec21
Successfully built python-etcd
Installing collected packages: urllib3, dnspython, python-etcd
Successfully installed dnspython-2.4.2 python-etcd-0.4.5 urllib3-2.0.4

```

## C++

<https://github.com/etcd-cpp-apiv3/etcd-cpp-apiv3>

## rust

<https://docs.rs/etcd/latest/etcd/>

<https://github.com/smallnest/rpcx-rs/tree/master/examples>

## node

<https://github.com/MattCollins84/etcd-service-discovery>