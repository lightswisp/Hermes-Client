class WSClient
  def initialize(script, logger)
    @script = script
    @logger = logger
    @browser = Ferrum::Browser.new(browser_options: { 'no-sandbox': nil })
    @connected = false
  end

  def close
    @browser.quit
  rescue StandardError
    puts('Browser is already closed.')
  end

  def ws_init
    Thread.new do
      @browser.go_to 'about:blank'
      @browser.execute(@script)
    end
  end

  def connected?
    return @browser.evaluate("window.ws_client_connected")
  end
end
