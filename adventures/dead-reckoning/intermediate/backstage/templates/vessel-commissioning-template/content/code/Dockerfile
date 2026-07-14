FROM golang:1.26-alpine AS builder
WORKDIR /app
COPY go.mod .
COPY main.go .
RUN go build -o server .

FROM alpine:3.24
COPY --from=builder /app/server /server
EXPOSE 8080
ENTRYPOINT ["/server"]
