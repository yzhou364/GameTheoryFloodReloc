import numpy as np
import pymysql

def listToMysql(tableName,fieldList,valueList):
    try:
        field = "";
        value = ""
        for i, j in zip(fieldList, valueList):
            field += i + ','
            value += "'" + j + "',"
        #print(value)
        sql = "INSERT INTO {} ({}) VALUES ({})".format(tableName, field[:-1], value[:-1])
        cursor.execute(sql)
    except Exception as e:
        print(str(e))

conn = pymysql.connect(
    host = "localhost",
    user = "root",
    password = "Meiguo2017!",
    database = "HOUSEPRICE")

cursor = conn.cursor()

with open('/Users/markzhou/PycharmProjects/Research/ZAsmtSaleData.txt') as f:
    line = 1
    while line:
        line = f.readline().strip('\n')
        if line:
            list = line.split('|')
            fieldList = ['ROW_ID','SALE_DATE','SALE_PRICE']
            valueList = [list[0],list[4],list[11]]
            listToMysql("SALEDATA",fieldList,valueList)
            conn.commit()
f.close()

#if conn:
    #print("data base has already connected")

conn.close()
