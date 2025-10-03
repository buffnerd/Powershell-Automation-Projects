DECLARE @Client_A_Contacts VARCHAR (30)

SET @Client_A_Contacts = 'Client_A_Contacts'

-- check if table exists, delete and recreate if so

IF (EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE

TABLE_NAME = @Client_A_Contacts))

BEGIN

print 'table ' + @Client_A_Contacts + ' already exists'

DROP TABLE dbo.Client_A_Contacts

END

BEGIN

CREATE TABLE Client_A_Contacts

(

first_name varchar(30),

last_name varchar(30),

city varchar (30),

county varchar (30),

zip varchar (30),

officePhone varchar (30),

mobilePhone varchar (30)

)

print 'table ' + @Client_A_Contacts + ' created'

END