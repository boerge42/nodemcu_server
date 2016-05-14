INSTALL_DIR=/usr/bin

install:
	dos2unix nodemcu_server.tcl
	dos2unix nodemcu_client.tcl
	cp nodemcu_server.tcl $(INSTALL_DIR)
	cp nodemcu_client.tcl $(INSTALL_DIR)
	chmod 0755 $(INSTALL_DIR)/nodemcu_server.tcl
	chmod 0755 $(INSTALL_DIR)/nodemcu_client.tcl
