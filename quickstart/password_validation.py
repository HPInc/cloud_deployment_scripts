#!/usr/bin/env python3

# Copyright (c) 2019 Teradici Corporation
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

import base64
import datetime
import getpass
import importlib
import json
import os
import re
import shutil
import site
import subprocess
import sys
import textwrap
import time

import cam
 
def ad_password_get():
    txt = r'''
    Please enter a password for the Active Directory Administrator.

    Note Windows passwords must be at least 7 characters long and meet complexity
    requirements:
    1. Must not contain user's account name or display name
    2. Must have 3 of the following categories:
       - a-z
       - A-Z
       - 0-9
       - special characters: ~!@#$%^&*_-+=`|\(){}[]:;"'<>,.?/
       - unicode characters
    See: https://docs.microsoft.com/en-us/windows/security/threat-protection/security-policy-settings/password-must-meet-complexity-requirements
    '''
    print(textwrap.dedent(txt))
    while True:
        password1 = getpass.getpass('Enter a password: ').strip()
        password2 = getpass.getpass('Re-enter the password: ').strip()

        if password1 == password2:
            print('')
            break

        print('The passwords do not match.  Please try again.')

    return password1

def ad_password_validate(password):
    #check length
    if len(password) < 7:
        return False
    
    count = 0
    response = "Successful. Password contains: "

    #check lowercase
    regex = "(?=.*[a-z])"
    pattern = re.compile(regex)
    match = re.search(pattern, password)
    if match:
        count += 1
        response += "a-z, "

    #check uppercase
    regex = "(?=.*[A-Z])"
    pattern = re.compile(regex)
    match = re.search(pattern, password)
    if match:
        count += 1
        response += "A-Z, "

    #check number
    regex = "(?=.*\d)"
    pattern = re.compile(regex)
    match = re.search(pattern, password)
    if match:
        count += 1
        response += "0-9, "

    #check special characters
    regex = "(?=.*[@$!%*#?&])"
    pattern = re.compile(regex)
    match = re.search(pattern, password)
    if match:
        count += 1
        response += "special characters, "
    
    #check 
    if f'b\'{password}\'' != f'{password.encode("utf-8")}':
        count += 1
        response += "unicode characters."
    
    if (count > 2):
        print(response)
        return True
    else:
        print("Warning: password do not meet the complexity requirements. Please try again.")
        return False

 
if __name__ == '__main__':   

    # For testing
    # Test #1: 123456
    # Test #2: SECure_3
    # Test #3: Ġabc123
    while (True):
        password = ad_password_get()
        if ad_password_validate(password):
            break