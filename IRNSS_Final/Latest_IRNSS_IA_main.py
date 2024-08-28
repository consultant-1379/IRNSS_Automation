from flask import Flask,flash,request,render_template,redirect,url_for
from hurry.filesize import size
import pymysql
import os
import csv
import re
import sys
import webbrowser

import paramiko
import subprocess
import glob
import socket
import glob, os
import time




app = Flask(__name__)
app.secret_key = 'random string'

#######Database connectivity
db = pymysql.connect(host="localhost",  # your host 
                     user="root",       # username
                     passwd="1234",     # password
                     db="irnss_automation")   # name of the databas
   
############Sacinng and polling 
def disk_usage(IP_Adress):   
   #print "IP_address is :",IP_Adress
   print "Truncating irn_diskusage_table"
   cursor = db.cursor()
   sql = "truncate irn_diskusage_table"
   cursor.execute(sql)
   db.commit()
  
   time.sleep(3)
   list_files=[]
   list_fe = ""
   i = 0
   df_cmd = "df -hk | sed '1 d' | "+"awk '{" + 'print $6 "|" $5 "|" $2}'+"'"
   #print df_cmd
   ssh_stdin, ssh_stdout, ssh_stderr = client.exec_command(df_cmd)
   df_us = ssh_stdout.read().strip()
   df_us = df_us.split("\n")
   for lin in df_us:
      lin = lin.split("|")
      lin0 = lin[0]
      lin1 = lin[1]
      lin1 = lin1.strip("%")
      lin2 = lin[2]
      if "/ossrc/sybdev/oss/sybdata" not in lin0 and "/ossrc/sybdev/oss/syblog" not in lin0:
         if not lin1:
            xyz = "empty"
         else :
               lin1 = int(lin1)
               if lin1 >= 88 :
                  #print("\nDirectory Name = {0:20} : Size ={1:50} : Total size = {2:50}".format (lin0,str(lin1)+"%",str(lin2)))
                  Directory_Name = lin0
                  Directory_Capacity = str(lin1)+"%"
                  Directory_Size = str(lin2)
                  print "-----------------------------------------------"
                  print "Directory size :",Directory_Size
                  if "g" in Directory_Size or "G" in Directory_Size:
                     Directory_Size = Directory_Size.strip("g").strip("G")
                     Directory_Size = float(Directory_Size) * (1024 * 1024 * 1024)
                     print "Directory_Size_Byte: ", Directory_Size
                  elif "M" in Directory_Size or "m" in Directory_Size:
                     Directory_Size = Directory_Size.strip("m").strip("m")
                     Directory_Size = float(Directory_Size) * (1024 * 1024)
                     print "Directory_Size_Byte: ", Directory_Size
                  else:
                     Directory_Size = Directory_Size.strip("k").strip("K")
                     Directory_Size = float(Directory_Size) * 1024
                     print "Directory_Size_Byte: ", Directory_Size

                     
                  Goal_per =  int(lin1) - 70
                  print "Size to deleted in Percenatge :", Goal_per
                  Goal_data = (float(Goal_per)/100)*Directory_Size
                  Goal_data = size(Goal_data)
                  print "Size to deleted :",Goal_data
                  print "-----------------------------------------------"
                  
                                    
                  i += 1
                  cmd = "cd "+lin0+";du -a *|sort -nr | head -5"
                  #print cmd
                  ssh_stdin, ssh_stdout, ssh_stderr = client.exec_command(cmd)
                  df_us_s = ssh_stdout.read().strip()
                  df_us_s = df_us_s.split("\n")
                  #print "----------------------------------------"
                  for line in df_us_s:
                     if len(line) >= 1:
                        line = line.split()
                        file_size = int(line[0])*512
                        
                        print "++++++++++++++++++++++++++++++++"
                        file_size = (file_size) / (1024)/(1024)
                        print file_size
                        #file_size = size(int(file_size))
                        #print file_size
                        print "++++++++++++++++++++++++++++++++" 

                        
                        
                        file_name = line[-1]
                        full_path_file = lin0+"/"+file_name.strip()
                        #print  file_size+" : " +lin0+"/"+file_name.strip()
                        output1= str(file_size)+":"+lin0+"/"+file_name.strip()
                        list_files.append(output1)
                        list_fe += "|"+output1 
                  #print list_files
                  #print list_fe
                  output_2 = str(list_files)
                  #print len(output_2)
                  cursor = db.cursor()            
                  cursor.execute("""INSERT INTO irn_diskusage_table(IP_ADDRESS,DISK_CAPACITY,DIRECTORY,FILE_PATH,SIZE_TO_DELETE)VALUES (%s,%s,%s,%s,%s)""",(IP_Adress,Directory_Capacity,Directory_Name,list_fe,Goal_data))      
                  db.commit()
                  list_files=[]
                  list_fe = ""



client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
#####Welcome page
@app.route('/')
def welcome_page():
   return render_template('welcome_page.html')


#####Server Login Page
@app.route('/Server_details',methods=['GET','POST'])
def server_details():
     error = None   
     global IP_Adress
     if request.method=='POST':
        IP_Adress=request.form['ip_address']
        User_Name=request.form['user_name']
        Password=request.form['password']
        print "IP Address: ",IP_Adress
        print "User Name: ",User_Name
        print "Password: ",Password
        cursor = db.cursor()     
        cursor.execute("SELECT USERNAME,IP_ADDRESS FROM irn_server_details_table where IP_ADDRESS=%s",(IP_Adress,))
        resu = cursor.fetchone()
        print "results:",resu
        if IP_Adress in str(resu) and User_Name in str(resu) :
                print "IP Address already added in databases"
                #flash('IP Address already added in databases')
                
                try:
                       client.connect(IP_Adress, username=User_Name ,password=Password)               
                except paramiko.SSHException:
                       print "Login issue: Please check the password"
                       error = 'Login issue: Please check the password'
                       return render_template('server_login.html',error = error)
                except paramiko.AuthenticationException:
                       print "Login issue: Please check the password"
                       error = 'Login issue: Please check the password'
                       return render_template('server_login.html',error = error)
                except (socket.error, paramiko.AuthenticationException):
                       print "Connection refused"
                       error = 'Connection refused'
                       return render_template('server_login.html',error = error)
                disk_usage(IP_Adress)          
                sucss_msg=["You were successfully logged in"]
                flash(sucss_msg)
                return redirect(url_for('Disk_Usage_Directory'))
        else:
                print "Adding details to irn_server_details_table"        
                try:
                       client.connect(IP_Adress, username=User_Name ,password=Password)               
                except paramiko.SSHException:
                       print "Login issue: Please check the password"
                       error = 'Login issue: Please check the password'
                       return render_template('server_login.html',error = error)
                except paramiko.AuthenticationException:
                       print "Login issue: Please check the password"
                       error = 'Login issue: Please check the password'
                       return render_template('server_login.html',error = error)
                except (socket.error, paramiko.AuthenticationException):
                       print "Connection refused"
                       error = 'Connection refused'
                       return render_template('server_login.html',error = error)
                    
                print "You were successfully logged in"
                
                cursor = db.cursor()            
                cursor.execute("""INSERT INTO irn_server_details_table(IP_ADDRESS,USERNAME,PASSWORD)VALUES (%s,%s,%s)""",(IP_Adress,User_Name,Password))       
                db.commit()
                disk_usage(IP_Adress)
                sucss_msg=["You were successfully logged in"]
                flash(sucss_msg)
                return redirect(url_for('Disk_Usage_Directory'))
     return render_template('server_login.html',error = error)





files_list=[]
def Disk_Usage_dir():
        global res
        global KEDB_da
        KEDB_data=[]
        KEDB_da = []
        res = ""
        cursor = db.cursor()
        sql = "SELECT DISK_CAPACITY,DIRECTORY,FILE_PATH FROM irn_diskusage_table"
        cursor.execute(sql)
        results = cursor.fetchall()
        print "Length of the disk_usage table:", len(results)
        if len(results) == 0:
           print "empty"
           return redirect(url_for('Disk_Usage_successful'))
        else:
           print "data exists"
           #print "results:",results
           res = str(results).replace("'" ,"").replace("[","").replace(" ","").replace("(","").replace(")","").replace("]","").replace('"',"")
           #print "results:",res
           res = res.strip()     
           ress = res.split(",")
           for lin in ress:
                 if len(lin)>0:
                    if "%" in lin:  
                       dir_capacity = lin
                       print "\nDIRECTORY CAPACITY :",dir_capacity
                    else:
                       if "|" in lin:
                          lin = lin.split("|")
                          for line in lin:
                             if ":" in line:
                                 line = line.split(":")
                                 file_size = line[-2]
                                 file_names = line[-1]
                                 #print "FILE NAME :"+file_names+":"+dir_name+":"+dir_capacity
                                 print "DIRECTORY:" +dir_name+" | FIlE SIZE:"+ file_size+" | FILE NAME:"+file_names
                                 
                                 cursor = db.cursor()
                                 sql = "SELECT * from irn_diskusage_knowledge_table where DIRECTORY='"+dir_name+ "' and FILE_PATH='"+file_names+"'"
                                 cursor.execute(sql)
                                 kedb_results = cursor.fetchall()
                                 
                                
                                 #print "KEDB Data :" ,kedb_results
                                 if len(kedb_results) >= 1:
                                    kedb_results = kedb_results + (file_size,)
                                    KEDB_data.append(kedb_results)
                                    
                                    
                                 
                       else:
                          dir_name = lin
                          print "DIRECTORY :", dir_name
                 
        print "\nKEDB DATAS:"
        for dat in KEDB_data:
           dat = str(dat)
           dat =  dat.replace("(","").replace(")","").replace("'","")
           dat = dat.split(",")
           KEDB_da.append(dat)
           
           print "IP address :", dat[0]
           print "COunt :", dat[1]
           print "Dir :", dat[2]
           print "File :", dat[3]
           print "Solution :", dat[4]
           print "File Size :", dat[5]
           
####Default and KEDB and Current usagae directory     
@app.route('/Disk_Usage_Directory', methods=['GET', 'POST'])
def Disk_Usage_Directory():
        Disk_Usage_dir()
        files_list=[]
        verify_files=[]
        sucss_msgs=[]
        if request.method == 'POST':
           checked_output = (request.form.getlist('checks'))
           print "\nChecked item on directory web page"
           for line in checked_output:
               print line
               files_list.append(line)
               
           if len(files_list) > 0:
            ################Delete Function
               
               if request.form['submit'] == 'DELETE':
                  print "\nDELETE OPTION SELECTED" 
                  for line in files_list:
                      print "Removing the selected files"
                      print "File:",line
                      if ":" in line:
                         remove_file = line.split(":")
                         remove_file = remove_file[1] 
                      else:
                         remove_file = str(line).strip()
                      remove_cmd = "rm -rf "+remove_file
                      ssh_stdin, ssh_stdout, ssh_stderr = client.exec_command(remove_cmd)
                      remove_output = ssh_stdout.read().strip()
                      print "Output : ",remove_output
                      print "Output Length:", len(remove_output)
                      print "Output error:", ssh_stderr.read()

                      print "\n*******Verify wheather file is deleted or not***********"
                      verify_cmd = "ls "+remove_file
                      ssh_stdin, ssh_stdout, ssh_stderr = client.exec_command(verify_cmd)
                      verify_output = ssh_stdout.read().strip()

                      if remove_file not in verify_output:
                         print "\n"
                         print remove_file," : File is successfully deleted"
                         verify_success=remove_file+" : File is successfully deleted"
                         verify_files.append(verify_success)
                         print "----------------------------------------------"
                         cursor = db.cursor()
                         sql = "SELECT DIRECTORY from irn_diskusage_table where FILE_PATH Like '%"+line+"%'"
                         cursor.execute(sql)
                         delete_results = cursor.fetchone()
                         print "deleted directory:",delete_results
                        
                         if not delete_results:
                            print "Empty nothing to print"
                         else:
                            for delete_data in delete_results:
                                 print "Directory : ", delete_data
                                 verif_dir_cmd = "df -hk "+delete_data+" | tail -1 |awk '{print $5}'"
                                 
                                 time.sleep(20)
                                 ssh_stdin, ssh_stdout, ssh_stderr = client.exec_command(verif_dir_cmd)
                                 verif_dir_capacity = ssh_stdout.read().strip()
                                 verif_dir_capacity = verif_dir_capacity.strip("%")
                                 print "\nverif_dir_capacity :", verif_dir_capacity
                                 if int(verif_dir_capacity) < 85:
                                    print "\n Issue resolved"
                                    cursor.execute("""INSERT INTO Temp_IRN_DISKUSAGE_TABLE(IP_ADDRESS,DIRECTORY,FILE_PATH)VALUES (%s,%s,%s)""",(IP_Adress,delete_data,remove_file))
                                    cursor = db.cursor()
                                    db.commit()
                                    sql = "SELECT * from Temp_IRN_DISKUSAGE_TABLE where DIRECTORY ='"+delete_data+"' and IP_ADDRESS='"+IP_Adress+"'"
                                    cursor.execute(sql)
                                    sucess_result= cursor.fetchall()
                                    print "--------------------------------------------"
                                    print "Successful result:"
                                    for line in sucess_result:
                                       #print line
                                       print "IP Address :",line[0]
                                       print "Directory  :",line[1]
                                       print "File       :",line[2]
                                       sql = "SELECT TIME,DIRECTORY,FILE_PATH,SOLUTION FROM irn_diskusage_knowledge_table where DIRECTORY='"+line[1]+"' and FILE_PATH='"+line[2]+"'"
                                       cursor.execute(sql)
                                       update_kedb = cursor.fetchone()
                                       print update_kedb

                                       if line[1] in str(update_kedb) and line[2] in str(update_kedb):
                                          print "already exits"
                                          Count = int(update_kedb[0])
                                          Count += 1
                                          print "Count is :", Count
                                          Count_update= "UPDATE irn_diskusage_knowledge_table SET TIME='"+str(Count)+"' WHERE DIRECTORY='"+line[1]+"' and FILE_PATH='"+line[2]+"'"
                                          cursor.execute(Count_update)
                                          db.commit()
                                       else:
                                          cursor.execute("""INSERT INTO irn_diskusage_knowledge_table(IP_ADDRESS,TIME,DIRECTORY,FILE_PATH,SOLUTION)VALUES (%s,%s,%s,%s,%s)""",(line[0],"1",line[1],line[2],"Delete"))
                                          cursor = db.cursor()
                                          db.commit()
                                       
                                    print "--------------------------------------------"
                                    
                                    del_sql="delete from temp_irn_diskusage_table where DIRECTORY ='"+delete_data+"' and IP_ADDRESS='"+IP_Adress+"'"
                                    cursor.execute(del_sql)
                                    db.commit()
                                    del_disk_sql="delete from irn_diskusage_table where DIRECTORY ='"+delete_data+"' and IP_ADDRESS='"+IP_Adress+"'"
                                    cursor.execute(del_disk_sql)
                                    db.commit()
                                    suuss_dir=delete_data+" : Disk Usage is now normal on the server"
                                    sucss_msgs.append(suuss_dir)
                                    
                                    #return redirect(url_for('Disk_Usage_successful'))
                                    #return redirect(url_for('Disk_Usage_Directory'))
                                 else:
                                    cursor.execute("""INSERT INTO Temp_IRN_DISKUSAGE_TABLE(IP_ADDRESS,DIRECTORY,FILE_PATH)VALUES (%s,%s,%s)""",(IP_Adress,delete_data,remove_file))
                                    cursor = db.cursor()
                                    db.commit()                        
                              
                         

                      else:
                         print remove_file," : File is not deleted"
                         verify_failed=remove_file+" : File is not deleted"
                         verify_files.append(verify_failed)
                
                  disk_usage(IP_Adress)
                  Disk_Usage_dir()
                  flash(verify_files)
                  flash(sucss_msgs)
                  #return render_template('directory_tables.html', results=res, KEDB_data=KEDB_da)
                  return redirect(url_for('Disk_Usage_Directory'))
               
               elif request.form['submit'] == 'MOVE':
                  print "MOVE OPTION SELECTED"
                  return redirect(url_for('Disk_Usage_Directory'))
               elif request.form['submit'] == 'ZIP':
                  print "ZIP OPTION SELECTED"
                  return redirect(url_for('Disk_Usage_Directory'))
               elif request.form['submit'] == 'INCREASE':
                  print "INCREASE OPTION SELECTED"
                  return redirect(url_for('Disk_Usage_Directory'))
               else:
                  print "UNKOWN OPTION"
                  return redirect(url_for('Disk_Usage_Directory'))
           else:
                  print "Did not clicked any files"
                  #disk_usage(IP_Adress)
        return render_template('directory_tables.html', results=res, KEDB_data=KEDB_da)


@app.route('/Disk_Usage_successful', methods=['GET', 'POST'])
def Disk_Usage_successful():
   return render_template('success.html')


if __name__=='__main__':
    url = 'http://127.0.0.1:5000'
    webbrowser.open_new(url)
    app.run()

   
