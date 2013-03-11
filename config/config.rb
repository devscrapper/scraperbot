require File.dirname(__FILE__) + "/../run/driver_em_ftpd.rb"
# configure the server
#driver_args "development"
driver     FTPDriver
#daemonise true
port 9152
#pid_file File.dirname(__FILE__) + "/../run/em_ftpd.pid"

#name      "ftpd"
#user      "ftp"
#group     "ftp"

