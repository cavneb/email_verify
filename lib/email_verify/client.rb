require 'dnsruby'
require 'net-telnet'

module EmailVerify
  class Client

    attr_accessor :email, :domain

    def verify(email)
      @email = email
      @domain = email.gsub(/.+@([^.]+.+)/, '\1')
      begin
        mx_domain = capture_mx_server
        response = verify_email(mx_domain)
        valid = response.last.include? 'OK'
        {
          valid: valid,
          response: response
        }
      rescue => ex
        {
          valid: false,
          error: ex.message
        }
      end
    end

    private

    def capture_mx_server
      resolver = Dnsruby::DNS.new
      ret = {}
      begin
        resolver.each_resource(domain, 'MX') do |rr|
          # print rr.preference, "\t", rr.exchange, "\n"
          ret[rr.preference] = rr.exchange
        end
      rescue Exception => e
        fatal_error("Can't find MX hosts for #{domain}: #{e}")
      end

      mx_domain = ret.sort.first[1].to_s
    end

    def verify_email(mx_domain)
      host = Net::Telnet::new("Host" => mx_domain, "Port" => 25, "Telnetmode" => false, "Timeout" => 30)
      response = []
      lines_to_send = ["HELO #{domain}", 'MAIL FROM:<eric@mxcheck.org>', "RCPT TO:<#{email}>"]
      lines_to_send.each do |line|
        host.puts(line)
        host.waitfor(/./) do |data|
          puts data
          response << data.strip
        end
      end
      host.close
      response
    end

  end
end
