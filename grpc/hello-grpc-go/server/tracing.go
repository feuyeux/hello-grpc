package server

type HelloTracing struct {
	xRequestId      string
	xB3TraceId      string
	xB3SpanId       string
	xB3ParentSpanId string
	xB3Sampled      string
	xB3Flags        string
	xOtSpanContext  string
}

func (t *HelloTracing) kv() []string {
	return []string{
		"x-request-id", t.xRequestId,
		"x-b3-traceid", t.xB3TraceId,
		"x-b3-spanid", t.xB3SpanId,
		"x-b3-parentspanid", t.xB3ParentSpanId,
		"x-b3-sampled", t.xB3Sampled,
		"x-b3-flags", t.xB3Flags,
		"x-ot-span-context", t.xOtSpanContext,
	}
}
