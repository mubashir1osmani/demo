''' in this file we are sending traces to arize phoenix from litellm, we are customizing metadata, span annotations to improve observability '''

from phoenix.otel import register

tracer_provider = register(project_name="default", auto_instrument=True, batch=False)

