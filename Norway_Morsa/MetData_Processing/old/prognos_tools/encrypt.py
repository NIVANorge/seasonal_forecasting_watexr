#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Wed Jan 10 12:37:09 2018

@author: jose-luis
"""

import base64
from cryptography.fernet import Fernet
import json
#import getpass


def encryptCredentials(database,username,host,databasePassword,encryptionKey):
    credentials = {}
    credentials['username'] = username;
    credentials['password'] = databasePassword
    credentials['database'] = database
    credentials['host'] = host
    s = json.dumps(credentials)
    s = bytes(s,'utf-8')
    #Generating key from password
    encryptionKey = encryptionKey.zfill(32)
    encryptionKey=base64.b64encode(bytes(encryptionKey,'utf-8'))
    f = Fernet(encryptionKey)
    token = f.encrypt(s)
    return token

def decryptCredentials(token,encryptionKey) :
    encryptionKey = encryptionKey.zfill(32)
    encryptionKey=base64.b64encode(bytes(encryptionKey,'utf-8'))
    f = Fernet(encryptionKey)
    s = f.decrypt(token).decode('utf-8')
    s = json.loads(s)
    return s
    

def encryptString(string,encryptionKey):
    s = bytes(string,'utf-8')
    #Generating key from password
    encryptionKey = encryptionKey.zfill(32)
    encryptionKey=base64.b64encode(bytes(encryptionKey,'utf-8'))
    f = Fernet(encryptionKey)
    token = f.encrypt(s)
    return token

def decryptString(token,encryptionKey) :
    encryptionKey = encryptionKey.zfill(32)
    encryptionKey=base64.b64encode(bytes(encryptionKey,'utf-8'))
    f = Fernet(encryptionKey)
    s = f.decrypt(token).decode('utf-8')
    return s
