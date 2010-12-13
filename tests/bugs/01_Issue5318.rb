
agent = agents.first
master_run = RemoteExec.new(master)  # get remote exec obj to master
agent_run = RemoteExec.new(agent)    # get remote exec obj to agent

# 0: Query master for filetimeout value
filetimeout=0
test_name="Issue5318 - query Puppet master for filetimeout value"
BeginTest.new(master, test_name)
result = master_run.do_remote("puppet --configprint all | grep filetimeout")
if ( result.exit_code == 0 ) then
  filetimeout = $1 if /filetimeout \= \'(\d+)\'/ =~ result.stdout
  puts "Master reported file timeout value of: #{filetimeout}"
else 
  puts "Master file timeout value not reported!" 
end
result.log(test_name)

# 1: Add notify to site.pp file on Master
test_name="Issue5318 - modify(1/2) site.pp file on Master"
BeginTest.new(master, test_name)
result = master_run.do_remote('echo notify{\"issue5318 original\":} >> /etc/puppetlabs/puppet/manifests/site.pp')
result.log(test_name)

# 2: invoke puppet agent
config_ver_org=""
test_name="Issue5318 - invoke puppet agent"
BeginTest.new(agent, test_name)
result = agent_run.do_remote("puppet agent --no-daemonize --verbose --onetime --test")
config_ver_org = $1 if /Applying configuration version \'(\d+)\'/ =~ result.stdout
result.log(test_name)

# 3: 2nd modify site.pp on Masster
test_name="Issue5318 - modify(2/2) site.pp on Master"
BeginTest.new(master, test_name)
result = master_run.do_remote('echo notify{\"issue5318 modified\":} >> /etc/puppetlabs/puppet/manifests/site.pp')
result.log(test_name)

# sleep for filetimeout reported via master, plus 2 secs
filetimeout+=2
sleep filetimeout

# 4: invoke puppet agent again
config_ver_mod=""
test_name="Issue5318 - step 4"
BeginTest.new(agent, test_name)
result = agent_run.do_remote("puppet agent --no-daemonize --verbose --onetime --test")
config_ver_mod = $1 if /Applying configuration version \'(\d+)\'/ =~ result.stdout
result.log(test_name)

# 5: comapre the results from steps 2 and 4
test_name="Issue5318 - Compare Config Versions on Agent"
BeginTest.new(agent, test_name)
if config_ver_org == config_ver_mod then 
  msg="Agent did not receive updated config: ORG #{config_ver_org} MOD #{config_ver_mod}"
  @fail_flag=1
elsif
  msg="Agent received updated config: ORG #{config_ver_org} MOD #{config_ver_mod}"
end
Action::Result.ad_hoc(agent,msg,@fail_flag).log(test_name)
