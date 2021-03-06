USE [buscador_development]
GO
/****** Object:  StoredProcedure [dbo].[webservice]    Script Date: 10/04/2015 05:48:16 p. m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[webservice] 
    -- Add the parameters for the stored procedure here 
     @lat as float, 
     @lon as float 
AS 
BEGIN

    Declare @Object as Int; 
    Declare @ResponseText as Varchar(8000); 
    Declare @Url as Varchar(MAX);

    select @Url = 'http://ws.geonames.org/countryCode?lat=' + CAST(@lat as varchar) + '&lng='+ cast(@lon as varchar) +'&type=xml'

    Exec sp_OACreate 'MSXML2.XMLHTTP', @Object OUT; 
    Exec sp_OAMethod @Object, 'open', NULL, 'get', @Url, 'false' 
    Exec sp_OAMethod @Object, 'send' 
    Exec sp_OAMethod @Object, 'responseText', @ResponseText OUTPUT      
    Exec sp_OADestroy @Object

    --load into Xml 
    Declare @XmlResponse as xml; 
    select @XmlResponse = CAST(@ResponseText as xml)  
    select @XmlResponse.value('(/geonames/country/countryName)[1]','varchar(50)') as CountryName

END

