
protobuf:
	docker build -t ngshell-base . --target=protobuf_builder
protobuf-rebuild:
	docker build --no-cache -t ngshell-base . --target=protobuf_builder


shell:
	docker build -t ngshell .

shell-rebuild:
	docker build -t ngshell --no-cache .