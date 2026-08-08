# 虚拟主机

演示基于 Host 头的路由分发，使用路由器的 host() 方法根据 HTTP Host 头部进行分发。

## 使用方法

```bash
cjpm build
./target/release/bin/main
# 测试: curl -H "Host: api.localhost" http://localhost:8080/
```
