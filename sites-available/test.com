upstream myapp {
    least_conn;
    server assw10.ing.puc.cl:3000;
    server assw11.ing.puc.cl:3000;
    server assw12.ing.puc.cl:3000;
    #sticky;
}
upstream mydashboard {
    least_conn;
    server assw10.ing.puc.cl:8081;
    server assw11.ing.puc.cl:8081;
    server assw12.ing.puc.cl:8081;
    #sticky;
}
upstream myapp1 {
    server assw10.ing.puc.cl:3000;

    server assw11.ing.puc.cl:3000 backup;
}
upstream myapp2 {
    server assw11.ing.puc.cl:3000;
    
    server assw12.ing.puc.cl:3000 backup;

}
upstream myapp3 {
    server assw12.ing.puc.cl:3000;
    
    server assw10.ing.puc.cl:3000 backup;

}
upstream login-app{
   server assw9.ing.puc.cl:3000;
}
lua_package_path "/usr/local/lib/lua/5.1/?.lua;;";
server {
  listen 80 default_server;
  listen [::]:80 default_server;

  server_name test.com www.test.com;

  location / {
          proxy_pass http://myapp;
          proxy_http_version 1.1;
          proxy_set_header Upgrade $http_upgrade;
          proxy_set_header Connection 'upgrade';
          proxy_set_header Host $host;
          proxy_cache_bypass $http_upgrade;

  }
  location /loaderio-f77df4b9074312f478d7f2f24b10a2a5.txt {
	  root /home/administrator/validation-files/;
  }
  location /chat {
          proxy_pass http://myapp;
          proxy_http_version 1.1;
          proxy_set_header Upgrade $http_upgrade;
          proxy_set_header Connection 'upgrade';
          proxy_set_header Host $host;
          proxy_cache_bypass $http_upgrade;
	  
  }
  location ~ /chat/chat_room/(\d+) {
	  set $chat_n $1;
	  set_by_lua $chat_server '
	    number = 0
            for i = 1,string.len(ngx.var.chat_n)
		do
		number = number + string.byte(ngx.var.chat_n,i)
	    end
	    return (number%3) +1  
         ';
          proxy_pass http://myapp$chat_server;
          proxy_http_version 1.1;
          proxy_set_header Upgrade $http_upgrade;
          proxy_set_header Connection 'upgrade';
          proxy_set_header Host $host;
          proxy_cache_bypass $http_upgrade;
          
  }
  location /css {
  	proxy_pass http://login-app;
  }
  location /socket.io {
          if ($http_referer ~ /chat/chat_room/(\d+)) {
		set $chat_n $1;
	  }
          set_by_lua $chat_server '
	    number = 0
            for i = 1,string.len(ngx.var.chat_n)
		do
		number = number + string.byte(ngx.var.chat_n,i)
	    end
	    return (number%3) +1
         ';
          proxy_pass http://myapp$chat_server;
          proxy_http_version 1.1;
          proxy_set_header Upgrade $http_upgrade;
          proxy_set_header Connection 'upgrade';
          proxy_set_header Host $host;
          proxy_cache_bypass $http_upgrade;
  }
  location /users {
          proxy_pass http://login-app;
          proxy_http_version 1.1;
          proxy_set_header Upgrade $http_upgrade;
          proxy_set_header Connection 'upgrade';
          proxy_set_header Host $host;
          proxy_cache_bypass $http_upgrade;
  }
  location /foursquare{
          proxy_pass http://login-app;
          proxy_http_version 1.1;
          proxy_set_header Upgrade $http_upgrade;
          proxy_set_header Connection 'upgrade';
          proxy_set_header Host $host;
          proxy_cache_bypass $http_upgrade;

  }
  location /dashboard {
          proxy_pass http://login-app;
          proxy_http_version 1.1;
          proxy_set_header Upgrade $http_upgrade;
          proxy_set_header Connection 'upgrade';
          proxy_set_header Host $host;
          proxy_cache_bypass $http_upgrade;

  }
  location /test {
    content_by_lua_block {
            local redis = require "redis"
            local red = redis:new()
            local ok,err = red:connect("127.0.0.1",6379)
            if not ok then
                    ngx.say("failed to connect: ",err)
                    return
            end
            ngx.say("me pude conectar al parecer")
            red:select(0)
            red:set("test","Its workiiiiiiing gud")
            local value = red:get("test")
            ngx.say("hola")
    }
  }
}
