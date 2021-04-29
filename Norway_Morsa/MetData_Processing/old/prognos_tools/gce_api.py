from google.oauth2 import service_account
from google.auth.transport.requests import AuthorizedSession
from google.cloud import storage
from fabric2 import Connection
import time
import os
import sys
import json
from subprocess import Popen, PIPE, CalledProcessError

class gce_api:
    
    URI = 'https://www.googleapis.com'
    
    CommonCalls = {'machineTypeList': 'https://www.googleapis.com/compute/v1/projects/{project}/zones/{zone}/machineTypes',
                   'imagesList':      'https://www.googleapis.com/compute/v1/projects/{project}/global/images',
                   'projectInfo':     'https://www.googleapis.com/compute/v1/projects/{project}',
                   'firewallList':    'https://www.googleapis.com/compute/v1/projects/{project}/global/firewalls',
                   'firewallResource':'https://www.googleapis.com/compute/v1/projects/{project}/global/firewalls/{firewallName}', 
                   'instances':       'https://www.googleapis.com/compute/v1/projects/{project}/zones/{zone}/instances',
                   'serialPort':      'https://www.googleapis.com/compute/v1/projects/{project}/zones/{zone}/instances/{instanceName}/serialPort',
                   'instanceInfo':    'https://www.googleapis.com/compute/v1/projects/{project}/zones/{zone}/instances/{instanceName}'
    }
    
    def __init__(self,json_key,properties,storage_key):
        
        self.properties = properties
        self.properties['keyFile'] = F'{os.path.join(self.properties["keyDir"],self.properties["instanceName"])}'
        self.properties['pubKeyFile'] = F'{self.properties["keyFile"] + ".pub"}'
        self.credentials = service_account.Credentials.from_service_account_file(json_key)
        self.credentials_storage = service_account.Credentials.from_service_account_file(storage_key)
        self.scoped_credentials = self.credentials.with_scopes(['https://www.googleapis.com/auth/cloud-platform'])
        self.storage_credentials = self.credentials_storage.with_scopes(['https://www.googleapis.com/auth/devstorage.full_control'])
        
        self.authed_session = AuthorizedSession(self.scoped_credentials)
        self.storage_session = AuthorizedSession(self.storage_credentials)
        os.environ['GOOGLE_APPLICATION_CREDENTIALS']=storage_key
        self.storage_client = storage.Client() #GOOGLE_APPLICATION_CREDENTIALS should have been set as an environment variable. This is shit but storage_client here can't seem to accept the path to the json file
    
   
    def waitUntilDone(func):
        def wrapper(self,*args,**kwargs):
            response = func(self,*args,**kwargs)
            if 'status' in response.keys() and response != None:
                while True: #response['status'] != "DONE":
                    display(response)
                    time.sleep(0.5)
                    response = func(self,*args,**kwargs)
                    
#                     display(response)
            else :
                response = None
            return response
        return wrapper
    
    def get(self,*args,**kwargs):
        self.method = "get"
        return self.selectRunType(*args,**kwargs)

    def post(self,*args,**kwargs):
        self.method = "post"
        return self.selectRunType(*args,**kwargs)
    
    def delete(self,*args,**kwargs):
        self.method = "delete"
        return self.selectRunType(*args,**kwargs)
    
    
    def selectRunType(self,*args,**kwargs):
        wait = kwargs.get('wait',False)
        kwargs.pop('wait',None)
        if not wait:
            result = self.runRequest(*args,**kwargs)
        else: 
            result = self.persistent(*args,**kwargs)
        return result
        
       
    def runRequest(self,*args,**kwargs):
        properties = kwargs.get('properties',None)
        if properties != None:
            self.properties = properties
        kwargs.pop('properties',None)
        call=gce_api.CommonCalls[args[0]].format(**self.properties)
        #display(kwargs)
        response = getattr(self.authed_session,self.method)(call,**kwargs)
#         display(call)
        if response.status_code == 200:
            return json.loads(response.text)
        else:
            display("Response code was {}. It might not have worked".format(response.status_code))
            return None
        
    def request_storage(self,url, payload='None', method='get'):
        if payload is 'None':
            return getattr(self.storage_session,method)(url)
        else:
            return getattr(self.storage_session,method)(url,json=payload)        
        
        
    @waitUntilDone
    def persistent(self,*args,**kwargs):
        return self.runRequest(*args,**kwargs)
    
    def create_bucket(self,name):
        return self.storage_client.create_bucket(name)
    
    
    def generateSSHKey(self):
        display('Generating ssh key...')
        c = Connection('localhost')
        c.local('rm -f "{keyFile}.*"'.format(**self.properties))
        c.local("echo 'yes' | ssh-keygen -t rsa -f {keyFile} -C {username}  -N '' ".format(**self.properties),hide='out')
        c.close()
        #p = Popen("echo 'yes' | ssh-keygen -t rsa -f {keyFile} -C {username} -N '' ".format(**self.properties),
        #              stdout=PIPE,
        #              shell=True,
        #              stderr=PIPE
        #               )
        #print(p.communicate())
        with open (self.properties['pubKeyFile'],'r') as f:
            display('Opening {}'.format(self.properties['pubKeyFile']))
            self.pub = f.read().strip()
            
    def setConnection(self):        
        self.connection = Connection(host=self.properties['ip'],
                       user=self.properties['username'],
                       connect_kwargs={"key_filename": self.properties['keyFile'],}
                       )
        #self.connection.open()
        
    def setSSHPort(self,ip='',inOffice='True'):
        #display(cloudInfo)
        ipList = ["151.157.0.0/16",]
        if not inOffice:
            ipList.append(ip)
            
        info = self.get('firewallList')
        firewalls = [i['name'] for i in info['items']]
        ssh = {
              "name" : "ssh",  
              "allowed": [
                {
                  "IPProtocol": "tcp",
                  "ports": [
                    "22",
                  ]
                }
              ],
              "sourceRanges": ipList,
              "targetTags": [
                "ssh"
              ]
            }

        if 'ssh' in firewalls:
            self.properties['firewallName'] = 'ssh'
            info = self.delete('firewallResource')
            display(info['operationType'],info['targetLink'])

        #Waiting until the firewall has been deleted
        info = self.get('firewallList')
        firewalls = [i['name'] for i in info['items']]

        while 'ssh' in firewalls:
            time.sleep(0.5)
            info=self.get('firewallList')
            firewalls = [i['name'] for i in info['items']]

        # Actually creating the firewall
        info = self.post('firewallList',json=ssh)
        display(info['operationType'],info['targetLink'])
        
    def setPostgresAccess(self,ip='',inOffice='True'):
        #display(cloudInfo)
        ipList = ["151.157.0.0/16",]
        if not inOffice:
            ipList.append(ip)
            
        info = self.get('firewallList')
        firewalls = [i['name'] for i in info['items']]
        item = {
              "name" : "postgres-firewall",  
              "allowed": [
                {
                  "IPProtocol": "tcp",
                  "ports": [
                    "5432",
                  ]
                }
              ],
              "sourceRanges": ipList,
              "targetTags": [
                "postgres"
              ]
            }

        if 'postgres-firewall' in firewalls:
            self.properties['firewallName'] = 'postgres-firewall'
            info = self.delete('firewallResource')
            display(info['operationType'],info['targetLink'])

        #Waiting until the firewall has been deleted
        info = self.get('firewallList')
        firewalls = [i['name'] for i in info['items']]

        while 'postgres-firewall' in firewalls:
            time.sleep(0.5)
            info=self.get('firewallList')
            firewalls = [i['name'] for i in info['items']]

        # Actually creating the firewall
        info = self.post('firewallList',json=item)
        display(info['operationType'],info['targetLink'])
        
        
    def runScript(self,file,getResults=False,out='results.txt'):
        self.connection.put(file)
        name = os.path.basename(file)
        self.connection.run('chmod +x {}'.format(name))
        self.connection.run('./{}'.format(name))
        if getResults:
            self.connection.get("results.txt",out)
        
    
    

    
    