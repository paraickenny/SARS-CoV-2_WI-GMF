# Python 2.7
# recommended use:
# check iontorrent server for report number, xx, from http://172.30.163.205/report/xx
# run script in the background using nohup and passing the xx number as an argument
# nohup python -u covidseq_manager.py xx &
# note -u tag forces script to write all output unbuffered to nohup.out
# monitor nohup.out for updates
# poll iontorrent server to determine when sequencing is complete, then download relevant bam files and
# initiate a bash script to process the resulting files.

import requests
from requests.auth import HTTPBasicAuth
from bs4 import BeautifulSoup
import time
import subprocess
import sys
from multiprocessing.pool import ThreadPool

start_time = time.time()

# report_id = raw_input ("enter the number of the report corresponding to the complete run e.g. for http://172.30.163.205/report/44/ use 44 :")
report_id = sys.argv[1]

report_url = "http://172.30.163.205/report/"+ report_id+ "/"
print "obtaining data from ", report_url
#url = "http://172.30.163.205/output/Home/Auto_user_S5-0023-13-SARS-CoV-2-Run-002_127_tn_044/plugin_out/downloads/"
#        http://172.30.163.205/output/Home/Auto_user_S5-0023-13-SARS-CoV-2-Run-002_127_tn/plugin_out/downloads/


# url = "http://kennylab.org"
response = requests.get(report_url, auth=HTTPBasicAuth('user', 'pass')) #replace user and pass with torrent server username and password
# parse html
page = str(BeautifulSoup(response.content))



# obtain run name to build url

run_location = page.find('Auto_user')
start_run = page.find('A', run_location-10)
end_run = page.find (' ', start_run +1)
run_name= page[start_run:end_run]


print "Run name: ", run_name

bam_url = "http://172.30.163.205/output/Home/" + run_name.strip() +"_" + report_id.zfill(3) + "/plugin_out/downloads/"

print "bam_url: ", bam_url

# need to wait for download page to be generated
# code below polls website to see if page exists.
# return of 404 error code causes 10 minute pause followed by re-checking

wait_for_page = 0

while wait_for_page == 0:
    response = requests.get(bam_url, auth=HTTPBasicAuth('user', 'pass'))  #replace user and pass with torrent server username and password
    # parse html
    if response.status_code == 404:
        print "waiting 10 mins. Runtime so far: ", str((time.time()-start_time)/60), " minutes"
        time.sleep(600)
    if response.status_code != 404:
        wait_for_page = 1

# check to see if bam files all written out
# bam files assumed written if size of html page does not grow in 10 mins (600 seconds)
bams_written = 0

while bams_written == 0:
    response = requests.get(bam_url, auth=HTTPBasicAuth('user', 'pass')) #replace user and pass with torrent server username and password

    test1_page = str(BeautifulSoup(response.content))
    time.sleep(600)   # 10 minute pause to compare page sizes. If same, assume all writing done.
    test2_page = str(BeautifulSoup(response.content))
    if len(test2_page) == len(test1_page):
        bams_written = 1

page = str(BeautifulSoup(response.content))

print "length of webpage: ", len(page)

prefix = bam_url

bamlist = []

def getURL(page):
    """

    :param page: html of web page (here: Python home page)
    :return: urls in that page
    """
    start_link = page.find("a href")
    #print " found one"
    #print page
    if start_link == -1:
        return None, 0
    start_quote = page.find('"', start_link)
    end_quote = page.find('"', start_quote + 1)
    url = page[start_quote + 1: end_quote]
    if "bam" in url and "bai" not in url:
        link = "curl -u ionuser:ionuser -o "+ url + " "+ prefix + url + " &"
        bamlist.append(link)
    return url, end_quote

while True:
    url, n = getURL(page)
    page = page[n:]
    if url:
        print(url)
    else:
        break

print bamlist

# write out a bash script to curl the files from the torrent server
print "Writing out a file of target bam files in targetlist.sh script for auto-retrieval from server..."
f = open("targetlist.sh", "wb")
f.write ("#!/bin/bash\n")
for b in bamlist:
    f.write(b)
    f.write ("\n")
f.write ("wait\n")
f.close()

print "Now calling auto_retrieve_and_hisat.sh"
#call a bash script which will chmod+x the targetlist.sh, run it, and do the hisat alignments
subprocess.call("./auto_retrieve_and_hisat.sh", shell=True)
