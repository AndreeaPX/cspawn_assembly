# cspawn_assembly
CSpawn - Exercise 4, page 48 in Giant Black Book of Computer Viruses. Add
a procedure to CSpawn which will demand a password before executing the host and will exit
without executing the host file if it doesn't get the right password.
The password will be different for each infected file and will be generated based on the host name - the pattern it this case is the host name + 'PASS' + a random generated number besed on the current time. (for example, if the host file is named Host1.com and the random number is 3, the password is HOST1PASS3).
