# 聊天服务器说明文档
---

git仓库：
* https://github.com/tap2joy/ChatBin.git 可执行文件仓库
* https://github.com/tap2joy/Protocols.git 协议库
* https://github.com/tap2joy/ChatClient.git 客户端
* https://github.com/tap2joy/CenterService.git 中心服
* https://github.com/tap2joy/ChatService.git 聊天服务
* https://github.com/tap2joy/Gateway.git 网关服

## 协议设计
1. TCP通信，设计了一个简单的包头，第一个4字节表示包长，第二个4字节表示协议ID，后面跟protobuf包体
2. 在common里面定义了通用的错误码，消息id和通用错误消息包
3. 使用bufio.NewScanner处理粘包问题
## 服务器结构
整个服务器分为3块：<b>中心服务器(CenterService)</b>，<b>聊天服务(ChatService)</b>和<b>网关服(Gateway)</b>
1. 中心服务器目前是做成单节点，负责服务注册和服务发现，以及在线玩家的管理。
2. 中心服务器3秒内未收到服务发来的心跳，则视为已超时，并定时清理超时的服务。
3. 聊天服务是主要的聊天功能所在，可水平扩展，会定时向中心服务器发送心跳包。
4. 网关服负责与客户端的长链接，并转发客户端的请求，以及服务器的推送消息。
5. 网关服会定时轮询最新可用的聊天服务列表，以实现服务发现功能。网关服是可以水平扩展的。
6. 客户端与网关服采用TCP长链接通信，服务器之间采用rpc通信
![alt text](http://www.tap2joy.com/images/server.png "服务器架构图")

## 服务器部署
1. 准备数据库。ChatService有用到postgresql数据库，创建好名字为chat_db的数据库，owner为postgres，密码为6个1，可在config/app.json中修改
   数据库相关操作：
   ```shell
    psql -U postgres -W 111111
    create database chat_db owner postgres;
    ```
2. 如过你是windows操作系统，直接拉取仓库：https://github.com/tap2joy/ChatBin.git，执行根目录下的start.bat即可开启服务器
3. 如果你想通过代码构建部署，那么需要先拉取仓库：
    1) https://github.com/tap2joy/CenterService.git
    2) https://github.com/tap2joy/ChatService.git
    3) https://github.com/tap2joy/Gateway.git
4. 在对应的目录下执行: 
    ```shell
    git submodule init
    git submodule update
    go build
    ```
5. 依次启动CenterService, ChatService, Gateway
    1) CenterService 监听的端口是9100
    2) ChatService 端口是在config/app.json里面配置
    3) Gateway grpc的端口配的是9109，针对客户端的端口是9108
6. 每个服务代码目录下都有restart.sh，在linux系统下可以直接执行: bash restart.sh 进行重启服务或新开服务
7. 支持容器部署，执行docker build命令打镜像，执行docker run启动

## 客户端的使用
1. 可以直接使用：https://github.com/tap2joy/ChatBin.git 下面ChatClient的exe启动客户端。
   配置默认连的远程云服，如果要连本地，则使用client_local.json.
2. 客户端启动后会显示网络连接成功，并自动拉取当前可用的聊天室列表。然后输入要进去的聊天室id和昵称，即可开始聊天
3. 输入：/popular n，会显示n 秒内使用频率最高的单词，如果没有会提示 empty，如果时间参数未传，会提示参数错误。
4. 输入：/stats [user] 会显示指定用户的本次在线时长，如果用户不存在，会提示 user not exist.
5. 输入：/switch [id] 会切换到指定id的聊天室，并自动拉取聊天记录
![alt text](http://www.tap2joy.com/images/chat.png "客户端截图")

## 相关算法
1. 敏感词过滤，采用的TrieTree字典树处理，匹配效率高
2. 最近n秒内高频词统计，这是一个相对低频的操作，采用的是实时拉取n秒内的聊天记录，遍历聊天记录后生成一个map[string]int，
   同时保留当前最高的频率和最高频率对应的词，这样遍历一次就可以得到频率最高的词。
3. 消息推送。在中心服务器上，存储了一份在线玩家数据，包括玩家当前的聊天室id，上线时间，所在gateway的地址。
   当ChatService要给指定聊天室发消息时，先到CenterService上面拉取到所有的在线用户列表，从中获取他们所在的gateway，
   调用grpc接口PushMessage，将消息发送到gateway，gateway再分发给不同的客户端。

## 性能指标和扩展性
1. Gateway可以水平扩展，用户可以连任意一个Gateway。后面可以做负载均衡，应该不会成为瓶颈。
2. ChatService可以水平扩展，无状态服务，目前采用随机算法进行负载均衡。但是依赖数据库，所以瓶颈就在数据库。
   解决数据库问题的方法有：加缓存，增加从库，数据库分片等方案
3. CenterService目前是单一节点，不过所承载的功能简单，但还是可能成为整个系统的瓶颈。
   可以考虑采用redis作为数据存储，改成无状态服务，从而可以水平扩展。还可以考虑将服务管理和用户管理拆开。

## 第三方库
1. protobuf: 通信协议
2. grpc：rpc调用
3. xorm: 数据库操作
4. pq：postgresql驱动
5. viper：json文件读取

## 单元测试
1. 进入test目录，执行go test
2. grpc测试，在test/shell目录下，执行对应的shell

## API
1. CenterService
    1) UserOnline 用户上线
        * 参数：
            * Name: 用户名字
            * Gate: 所在gateway地址
            * Channel: 聊天室id
        * 返回：
            * OldUser: 如果当前用户已经在其他gate登录了，则返回老的用户信息，否则为空
    2) UserOffline 用户下线
        * 参数：
            * Name: 用户名字
    3) ChangeChannel 切换聊天室
        * 参数：
            * Name: 用户名字
            * Channel: 目标聊天室id
    4) GetUserOnlineTime 获取用户在线时长
        * 参数：
            * Name: 用户名字
        * 返回：
            * Duration: 在线时长，单位秒
    5) GetOnlineUsers 获取在线用户列表
        * 参数：
            * Channel: 聊天室id
        * 返回：
            * Users: 用户列表
    6) RegisterService 注册服务
        * 参数：
            * Type：服务类型
            * Address: 服务地址
    7) GetServices 获取可用服务列表
        * 参数：
            * Type：服务类型
        * 返回：
            * List：服务列表

2. ChatService
    1) SendMessage 发送聊天消息
        * 参数：
            * SenderName：发送者名字
            * Channel：聊天室id
            * Content：内容
            * System：是否是系统消息
        * 返回：
            * Result：gm命令的返回值
    2) GetChatLog 获取聊天记录
        * 参数：
            * Channel：聊天室id
        * 返回：
            * Logs：聊天记录
    3) GetChannelList 获取聊天室列表
        * 返回：
            * List：聊天室列表

3. Gateway
    1) PushMessage 推送消息
        * 参数：
            * SenderName：发送者名字
            * Content：内容
            * UserNames：目标玩家列表
            * Timestamp：时间戳
    2) KickUser 踢出用户
        * 参数：
            * Name: 用户名字
            * Gate: 网关地址