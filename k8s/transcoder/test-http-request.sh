echo "[test talk] curl http://localhost:9990/v1/talk/0/java"
curl http://localhost:9990/v1/talk/0/java
echo
echo "[test talk1n] http://localhost:9990/v1/talk1n/0,1,2/java"
curl http://localhost:9990/v1/talk1n/0,1,2/java
echo
echo "[test talkn1] curl -XPOST http://localhost:9990/v1/talkn1"
curl -XPOST http://localhost:9990/v1/talkn1 \
  -H 'Content-Type: application/json' \
  -d '[
    {
        "data":"0",
        "meta":"java"
    },
    {
        "data":"1",
        "meta":"java"
    }
]'
echo
echo "[test talknn] curl -XPOST http://localhost:9990/v1/talknn"
curl -XPOST http://localhost:9990/v1/talknn \
  -H 'Content-Type: application/json' \
  -d '[
    {
        "data":"2",
        "meta":"java"
    },
    {
        "data":"3",
        "meta":"java"
    }
]'