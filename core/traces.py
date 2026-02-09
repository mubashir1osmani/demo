from phoenix.otel import register

tracer_provider = register(project_name="default", auto_instrument=True, batch=False)

