class WSClient
  def initialize(script)
  	@script = script
    @browser = Ferrum::Browser.new(browser_options: { 'no-sandbox': nil })
    @connected = false
  end

  def close
		begin
			@browser.quit
		rescue StandardError
			puts('Browser is already closed.')
		end
  end

  def ws_init
  	Thread.new{
	    @browser.go_to 'about:blank'
	    @browser.execute(@script)
	    LOGGER.info('Initializing the connection...')
		}
  end

end
