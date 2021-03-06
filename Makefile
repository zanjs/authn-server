PKGS := $(shell glide nv)

.PHONY: clean
clean:
	rm -rf vendor
	rm -rf dist
	rm -f authn
	rm -f api/views/*.ego.go

# Code generation (ego)
.PHONY:
generate:
	go generate github.com/keratin/authn-server/api/views

# Fetch dependencies
vendor:
	glide install
	go install

# Build the project
.PHONY: build
build: generate vendor
	mkdir -p dist
	CGO_ENABLED=1 go build -o dist/authn

.PHONY: build-builder
build-builder:
	docker build -f Dockerfile.builder -t keratin/authn-server-builder .

.PHONY: docker
docker: build-builder
	docker run --rm \
		-v $(PWD):/go/src/github.com/keratin/authn-server \
		-w /go/src/github.com/keratin/authn-server \
		keratin/authn-server-builder \
		make clean build
	docker build --tag keratin/authn-server:latest .

# Run the server
.PHONY: server
server: vendor generate
	docker-compose up -d redis
	DATABASE_URL=sqlite3://localhost/dev \
		REDIS_URL=redis://127.0.0.1:8701/11 \
		go run *.go

# Run tests
.PHONY: test
test: vendor generate
	docker-compose up -d
	TEST_REDIS_URL=redis://127.0.0.1:8701/12 \
	  TEST_MYSQL_URL=mysql://root@127.0.0.1:8702/authnservertest \
	  go test $(PKGS)

# Run CI tests
.PHONY: ci
test-ci:
	TEST_REDIS_URL=redis://127.0.0.1/1 \
	  TEST_MYSQL_URL=mysql://root@127.0.0.1/test \
	  go test -race $(PKGS)

# Run migrations
.PHONY: migrate
migrate:
	go run *.go migrate
