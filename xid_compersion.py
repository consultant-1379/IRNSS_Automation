import sys
import ConfigParser
import csv
import os
import re

def get_table_details():

    with open('main.csv', 'r') as csvfile:
        
           next(csvfile, None)
           ofile  = open('final_product.csv', "wb")
           writer = csv.writer(ofile, delimiter=';',quoting=csv.QUOTE_ALL)
           writer.writerow(["XID", "Email ID"])
           for row in csvfile:
               row = row.split(",")
               r = row[6].strip()

               with open("zcop.csv", "r") as f:
                   reader = csv.reader(f,delimiter = ",")
                   next(reader,None)
                   tal_apend = list(reader)
                   for line in tal_apend:      
                       if r == line[0].strip():  
                            print r,row[4],line[0],line[1],line[2],line[3]
                            writer.writerow([r,row[4],line[0],line[1],line[2],line[3]])
                           
                        
                        

get_table_details()
