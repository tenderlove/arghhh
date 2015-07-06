require 'ds9'
require 'socket'
require 'openssl'

raise "wrong version of nghttp2" unless DS9.nghttp_version == '1.0.2'

module DS9
  class Context
    SETTINGS = [ ]

    def initialize pubkey, privkey
      @ctx               = OpenSSL::SSL::SSLContext.new
      @ctx.ssl_version   = "SSLv23_server"
      @ctx.cert          = OpenSSL::X509::Certificate.new File.read ARGV[0]
      @ctx.key           = OpenSSL::PKey::RSA.new File.read ARGV[1]
      @ctx.npn_protocols = [DS9::NGHTTP2_PROTO_VERSION_ID]
      server             = TCPServer.new 8080
      @server            = OpenSSL::SSL::SSLServer.new server, @ctx
      @server.setsockopt Socket::IPPROTO_TCP, Socket::TCP_NODELAY, 1
    end

    class MySession < DS9::Server
      def initialize sock
        super()
        @sock = sock
        @read_streams = {}
        @write_streams = {}
      end

      def on_begin_headers frame
        p __method__ => frame
      end

      def on_data_source_read stream_id, length
        x = @write_streams[stream_id].read(length)
        p __method__ => [stream_id, length, x]
        x
      end

      def on_frame_not_send frame, reason
        p __method__ => frame
      end

      def on_stream_close id, error_code
        @read_streams.delete id
        @write_streams.delete id
        p :CLOSING => id
      end

      def on_header name, value, frame, flags
        p __method__ => [name, value]
      end

      def on_frame_recv frame
        p __method__ => frame

        return unless frame.headers?

        @write_streams[frame.stream_id] = StringIO.new("hello world\n")

        submit_response frame.stream_id, [
          [":status", '200'],
          ["server", 'test server'],
          ["date", 'Sat, 27 Jun 2015 17:29:21 GMT']
        ]
        true
      end

      def on_frame_send frame
        p __method__ => [frame, frame.stream_id]
        true
      end

      def send_event string
        p __method__ => string
        @sock.write string
      end

      def recv_event length
        return '' unless want_read? || want_write?

        x = @sock.read_nonblock length
        p __method__ => [length, x, x.length]
        x
      rescue OpenSSL::SSL::SSLErrorWaitReadable
        p __method__ => "WOULD BLOCK"
        return DS9::ERR_WOULDBLOCK
      rescue EOFError
        p __method__ => "EOF"
        return DS9::ERR_EOF
      end

      def run
        while want_read? || want_write?
          if want_read?
            rd, _, _ = IO.select([@sock])
            receive
          end

          if want_write?
            _, wr, _ = IO.select(nil, [@sock])
            send
          end
        end
      end
    end

    def run
      loop do
        sock = @server.accept
        sock.setsockopt Socket::IPPROTO_TCP, Socket::TCP_NODELAY, 1
        puts "OMG"

        session = MySession.new sock
        session.submit_settings SETTINGS
        session.run
      end
    end
  end
end

ctx = DS9::Context.new ARGV[0], ARGV[1]
ctx.run

