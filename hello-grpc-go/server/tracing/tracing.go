package tracing

type HelloTracing struct {
	RequestId      string
	B3TraceId      string
	B3SpanId       string
	B3ParentSpanId string
	B3Sampled      string
	B3Flags        string
	OtSpanContext  string
}

func (t *HelloTracing) Kv() []string {
	return []string{
		"x-request-id", t.RequestId,
		"x-b3-traceid", t.B3TraceId,
		"x-b3-spanid", t.B3SpanId,
		"x-b3-parentspanid", t.B3ParentSpanId,
		"x-b3-sampled", t.B3Sampled,
		"x-b3-flags", t.B3Flags,
		"x-ot-span-context", t.OtSpanContext,
	}
}
