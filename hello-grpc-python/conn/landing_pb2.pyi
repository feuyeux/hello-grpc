from google.protobuf.internal import containers as _containers
from google.protobuf.internal import enum_type_wrapper as _enum_type_wrapper
from google.protobuf import descriptor as _descriptor
from google.protobuf import message as _message
from typing import ClassVar as _ClassVar, Iterable as _Iterable, Mapping as _Mapping, Optional as _Optional, Union as _Union

DESCRIPTOR: _descriptor.FileDescriptor

class ResultType(int, metaclass=_enum_type_wrapper.EnumTypeWrapper):
    __slots__ = ()
    OK: _ClassVar[ResultType]
    FAIL: _ClassVar[ResultType]
OK: ResultType
FAIL: ResultType

class TalkRequest(_message.Message):
    __slots__ = ("data", "meta")
    DATA_FIELD_NUMBER: _ClassVar[int]
    META_FIELD_NUMBER: _ClassVar[int]
    data: str
    meta: str
    def __init__(self, data: _Optional[str] = ..., meta: _Optional[str] = ...) -> None: ...

class TalkResponse(_message.Message):
    __slots__ = ("status", "results")
    STATUS_FIELD_NUMBER: _ClassVar[int]
    RESULTS_FIELD_NUMBER: _ClassVar[int]
    status: int
    results: _containers.RepeatedCompositeFieldContainer[TalkResult]
    def __init__(self, status: _Optional[int] = ..., results: _Optional[_Iterable[_Union[TalkResult, _Mapping]]] = ...) -> None: ...

class TalkResult(_message.Message):
    __slots__ = ("id", "type", "kv")
    class KvEntry(_message.Message):
        __slots__ = ("key", "value")
        KEY_FIELD_NUMBER: _ClassVar[int]
        VALUE_FIELD_NUMBER: _ClassVar[int]
        key: str
        value: str
        def __init__(self, key: _Optional[str] = ..., value: _Optional[str] = ...) -> None: ...
    ID_FIELD_NUMBER: _ClassVar[int]
    TYPE_FIELD_NUMBER: _ClassVar[int]
    KV_FIELD_NUMBER: _ClassVar[int]
    id: int
    type: ResultType
    kv: _containers.ScalarMap[str, str]
    def __init__(self, id: _Optional[int] = ..., type: _Optional[_Union[ResultType, str]] = ..., kv: _Optional[_Mapping[str, str]] = ...) -> None: ...
