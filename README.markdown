# I can't get SSL to work

This project is supposed to be an example HTTP2 server for Ruby.  I am using
[DS9](https://github.com/tenderlove/ds9) for parsing and emitting HTTP 2 responses,
but I am trying to write the SSL server using OpenSSL and it is not working.

I'll write how to get this up and running, then explain the problem I'm seeing.

## Hacking

First make sure to install `nghttp2`.  On OS X, it is like this:

```
$ brew install nghttp2
```

Then do this:

```
$ bundle install
$ bundler exec ruby server.rb public.pem private.pem
```

You should have the HTTP2 server running.  In a different terminal do this:

```
$ nghttp https://localhost:8080/
```

The output should say "hello world".  Now try browsing `https://localhost:8080/`
in the latest Chrome or Firefox, and you will get an EOF error.  I can't figure
out why I'm getting an EOF error.

## The Problem

If you follow the steps in `Hacking`, you'll see that the `nghttp` client can make
successful requests to the server, but using Chrome or Firefox will result
in an EOF error.  I can't figure out why.

I think it is an SSL handshake problem, and here is why:

If I run `nghttpd` like this:

```
$ nghttpd -v 8080 private.pem public.pem
```

Then in a different terminal I run `ssldump` like this:

```
$ sudo ssldump -a -d -A -H  -i lo0
```

Then I see an exchange like this:

```
6 4  0.0013 (0.0000)  S>CV3.3(333)  Handshake
      ServerKeyExchange
6 5  0.0013 (0.0000)  S>CV3.3(4)  Handshake
      ServerHelloDone
6 6  0.0028 (0.0014)  C>SV3.3(70)  Handshake
      ClientKeyExchange
6 7  0.0028 (0.0000)  C>SV3.3(1)  ChangeCipherSpec
6 8  0.0028 (0.0000)  C>SV3.3(40)  Handshake
6 9  0.0029 (0.0001)  C>SV3.3(48)  application_data
6 10 0.0030 (0.0000)  C>SV3.3(45)  application_data
6 11 0.0030 (0.0000)  C>SV3.3(37)  application_data
6 12 0.0031 (0.0001)  C>SV3.3(268)  application_data
6 13 0.0031 (0.0000)  S>CV3.3(1)  ChangeCipherSpec
6 14 0.0031 (0.0000)  S>CV3.3(40)  Handshake
6 15 0.0032 (0.0001)  S>CV3.3(39)  application_data
6 16 0.0033 (0.0000)  C>SV3.3(33)  application_data
6 17 0.0036 (0.0002)  S>CV3.3(259)  application_data
6    5.3703 (5.3667)  S>C  TCP FIN
6    5.3706 (0.0003)  C>S  TCP FIN
```

If I do the same thing, but with my Ruby server, I see this:

```
1 4  0.0033 (0.0000)  S>CV3.3(527)  Handshake
      ServerKeyExchange
1 5  0.0033 (0.0000)  S>CV3.3(4)  Handshake
      ServerHelloDone
1 6  0.0049 (0.0015)  C>SV3.3(134)  Handshake
      ClientKeyExchange
1 7  0.0049 (0.0000)  C>SV3.3(1)  ChangeCipherSpec
1 8  0.0049 (0.0000)  C>SV3.3(60)  Handshake
1 9  0.0049 (0.0000)  C>SV3.3(40)  Handshake
1 10 0.0056 (0.0006)  S>CV3.3(218)  Handshake
1 11 0.0056 (0.0000)  S>CV3.3(1)  ChangeCipherSpec
1 12 0.0056 (0.0000)  S>CV3.3(40)  Handshake
1    0.0063 (0.0007)  C>S  TCP FIN
```

In the good case, the browser sends a handshake followed by application data.
In this case, the server sends a handshake and the browser seems to kill the
connection.

## Things I've tried

I've tried changing the cipher list to [be like the one in nghttp2](https://github.com/tatsuhiro-t/nghttp2/blob/d10228cdf7c95198a9dc0c2d0781fc3eb8af2f88/src/HttpServer.cc#L1786).

I've tried [setting the same options](https://github.com/tatsuhiro-t/nghttp2/blob/d10228cdf7c95198a9dc0c2d0781fc3eb8af2f88/src/HttpServer.cc#L1776-L1784).

It looks like the server in the nghttp2 repo [uses ALPN](https://github.com/tatsuhiro-t/nghttp2/blob/d10228cdf7c95198a9dc0c2d0781fc3eb8af2f88/src/HttpServer.cc#L710-L727).  OpenSSL in Ruby doesn't support that, so I added it and changed the server to have ALPN support and that didn't work.  [Here is the patch I wrote to add ALPN support](https://gist.github.com/tenderlove/b19bdea0d98fd1c0b655) (which I will get upstreamed if I can prove that it is what we need).

## Things I haven't tried

I couldn't figure out how to use WireShark, so I was relying on `ssldump`.  Beyond that, I'm not sure.

# THE END

THANKS FOR READING THIS AND YOUR HELP!!
