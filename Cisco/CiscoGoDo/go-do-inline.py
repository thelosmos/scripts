# Import Libraries
import paramiko
import re
import getpass
import time
import sys

# Disable paging
def DISABLE_PAGING(remoteConn):
    '''Disable paging on a Cisco router'''

    remoteConn.send("terminal length 0\n")
    time.sleep(1)

    # Clear the buffer on the screen
    output = remoteConn.recv(1000)

    return output

if __name__ == '__main__':
    # Login prompt
    print(
    '''
    ######################################################################
    ### Please enter in connection information and command to be used. ###
    ######################################################################
    '''
        )
    ip = sys.argv[1]
    username = input("Username:")
    password = getpass.getpass("User Password:")
    enablePassword = getpass.getpass("Enable Password:")
    command = sys.argv[2]

    # Create instance of SSHClient object
    remoteConnPre = paramiko.SSHClient()

    # Automatically add untrusted hosts (make sure okay for security policy in your environment)
    remoteConnPre.set_missing_host_key_policy(
        paramiko.AutoAddPolicy())
    
    # Initiate SSH connection
    remoteConnPre.connect(ip, username=username, password=password, look_for_keys=False, allow_agent=False)
    remoteConn = remoteConnPre.invoke_shell()
    print("Interactive SSH Connection Established to %s" % ip)

    # Enter privileged exec mode
    output = remoteConn.recv(1000000)
    outputStr = output.decode('utf-8')
    if (outputStr.endswith('#')):
        print("In privileged mode.")
    else:
        print("Attepting to enter privileged mode.")
        remoteConn.send("enable")
        remoteConn.send("\n")
        remoteConn.send(enablePassword)
        remoteConn.send("\n")
        time.sleep(1)
        output = remoteConn.recv(1000000)
        outputStr = output.decode('utf-8')
        if (outputStr.endswith('#')):
            print("In privileged mode.")
        else:
            print("Could not enter privileged mode.")
            exit()

    # Disable paging
    DISABLE_PAGING(remoteConn)

    # Send command
    remoteConn.send(command)
    remoteConn.send("\n")
    time.sleep(2)
    output = remoteConn.recv(1000000)
    outputStr = output.decode('utf-8')

    # Show command result
    print(outputStr)

    # Close connection
    remoteConn.close()
    print("Interactive SSH Connection to %s closed." %ip)