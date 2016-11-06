# vim:set ft=nginx ts=4 sw=4 et:

use Test::Nginx::Socket::Lua no_plan;
use Cwd qw(cwd);

repeat_each(2);
no_shuffle();

my $pwd = cwd();

our $HttpConfig = qq{
    lua_package_path "$pwd/lib/?.lua;;";
    lua_package_cpath "/usr/local/openresty-debug/lualib/?.so;/usr/local/openresty/lualib/?.so;;";
    lua_socket_log_errors off;
};

$ENV{TEST_NGINX_FTP_PORT} ||= 21;
$ENV{TEST_NGINX_FTP_DIR} ||= cwd();

no_long_string();
#no_diff();

run_tests();

__DATA__

=== TEST 1: mkdir and rmdir
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua '
            local ftpclient = require "resty.ftpclient"

            local ftp = ftpclient:new()
            ftp:set_timeout(1000)
            local res,err = ftp:connect({
                host = "127.0.0.1",
                port = $TEST_NGINX_FTP_PORT,
                user = "ftpuser",
                password = "123456"
            })
            if not res then
                ngx.say("failed to connect: ", err)
                return
            end

            local res, err = ftp:mkd("data")
            if not res then
                ngx.say("failed to mkd ", err)
                return
            end
            ngx.say(res)

            local res, err = ftp:rmd("data")
            if not res then
                ngx.say("failed to rmd ", err)
                return
            end
            ngx.say(res)

            ftp:close()

        ';
    }
--- request
GET /t
--- response_body
257 "/data" created
250 Remove directory operation successful.
--- no_error_log
[error]


=== TEST 2: put, get and dele
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua '
            local ftpclient = require "resty.ftpclient"
            local cjson = require "cjson"

            local ftp = ftpclient:new()
            ftp:set_timeout(1000)
            local res,err = ftp:connect({
                host = "127.0.0.1",
                port = $TEST_NGINX_FTP_PORT,
                user = "ftpuser",
                password = "123456"
            })
            if not res then
                ngx.say("failed to connect: ", err)
                return
            end

            local file = io.open("$TEST_NGINX_FTP_DIR/tmp/a.txt")
            local str = file:read("*a")
            file:close()
            ngx.say(ngx.md5(str))

            local res,err = ftp:put("a.txt", str)
            if not res then
                ngx.say("failed to put: ", err)
                return
            end

            --get
            local str,err = ftp:get("a.txt")
            if not str then
                ngx.say("failed to get: ", err)
                return
            end
            ngx.say(ngx.md5(str))

            local res, err = ftp:dele("a.txt")
            if not res then
                ngx.say("failed to dele: ", err)
                return
            end
            ngx.say(res)

            ftp:close()

        ';
    }
--- request
GET /t
--- response_body
ba1f2511fc30423bdbb183fe33f3dd0f
ba1f2511fc30423bdbb183fe33f3dd0f
250 Delete operation successful.
--- no_error_log
[error]
