ROOTPATH=$PWD
ROOTDIR=$PWD
SOURCEPATH=$ROOTPATH/src

add_sql_container()
{
    if [ $( docker ps -a | grep azuresqledge | wc -l ) -gt 0 ]; then
        echo "azuresqledge exists"
    else
        echo "installing azure sql edge"
        sudo docker run -d --name azuresqledge -h $1 -e 'ACCEPT_EULA=Y' -e 'SA_PASSWORD=yourStrongP@ssword' -p 1433:1433 mcr.microsoft.com/azure-sql-edge
        docker cp ./build azuresqledge:/build
    fi
}

while [ -z "$APPNAME" ]; do
    read -p "Enter your app name: " APPNAME
done
## read -p "Enter your SQL server name [localhost]: " SQLSERVER
SQLSERVER=127.0.0.1:1433

dotnet new -i EPiServer.Net.Templates --nuget-source https://nuget.optimizely.com/feed/packages.svc/ --force
dotnet tool update EPiServer.Net.Cli --global --add-source https://nuget.optimizely.com/feed/packages.svc/
dotnet nuget add source https://nuget.optimizely.com/feed/packages.svc -n Optimizely
##dotnet dev-certs https --trust

dotnet build
add_sql_container

cms_db=$APPNAME.Cms
commerce_db=$APPNAME.Commerce
user=$APPNAME.User
password=Episerver123!
export SQLCMDPASSWORD=yourStrongP@ssword
errorMessage="" 

mkdir "$ROOTPATH/Build/Logs" 2>nul

cd src/Foundation/
npm ci
npm run dev
cd ../..

#docker exec -it sql_server_optimizely /opt/mssql-tools/bin/sqlcmd -S $SQLSERVER -U SA -P $password -Q "EXEC msdb.dbo.sp_delete_database_backuphistory N'$cms_db'"
#docker exec -it sql_server_optimizely /opt/mssql-tools/bin/sqlcmd -S $SQLSERVER -U SA -P $password -Q "if db_id('$cms_db') is not null ALTER DATABASE [$cms_db] SET SINGLE_USER WITH ROLLBACK IMMEDIATE"
#docker exec -it sql_server_optimizely /opt/mssql-tools/bin/sqlcmd -S $SQLSERVER -U SA -P $password -Q "if db_id('$cms_db') is not null DROP DATABASE [$cms_db]"
#docker exec -it sql_server_optimizely /opt/mssql-tools/bin/sqlcmd -S $SQLSERVER -U SA -P $password -Q "EXEC msdb.dbo.sp_delete_database_backuphistory N'$commerce_db'"
#docker exec -it sql_server_optimizely /opt/mssql-tools/bin/sqlcmd -S $SQLSERVER -U SA -P $password -Q "if db_id('$commerce_db') is not null ALTER DATABASE [$commerce_db] SET SINGLE_USER WITH ROLLBACK IMMEDIATE"
#docker exec -it sql_server_optimizely /opt/mssql-tools/bin/sqlcmd -S $SQLSERVER -U SA -P $password -Q "if db_id('$commerce_db') is not null DROP DATABASE [$commerce_db]"
echo "Executing database prep steps"
./sqlcmd -S $SQLSERVER -U SA -Q "EXEC msdb.dbo.sp_delete_database_backuphistory N'$cms_db'"
./sqlcmd -S $SQLSERVER -U SA -Q "if db_id('$cms_db') is not null ALTER DATABASE [$cms_db] SET SINGLE_USER WITH ROLLBACK IMMEDIATE"
./sqlcmd -S $SQLSERVER -U SA -Q "if db_id('$cms_db') is not null DROP DATABASE [$cms_db]"
./sqlcmd -S $SQLSERVER -U SA -Q "EXEC msdb.dbo.sp_delete_database_backuphistory N'$commerce_db'"
./sqlcmd -S $SQLSERVER -U SA -Q "if db_id('$commerce_db') is not null ALTER DATABASE [$commerce_db] SET SINGLE_USER WITH ROLLBACK IMMEDIATE"
./sqlcmd -S $SQLSERVER -U SA -Q "if db_id('$commerce_db') is not null DROP DATABASE [$commerce_db]"


echo "before create db"
dotnet episerver create-cms-database "./src/Foundation/Foundation.csproj" -S 127.0.0.1,1433 -U sa -P yourStrongP@ssword --database-name "$cms_db"  --database-user $user --database-password $password
echo "middle of create db"
dotnet episerver create-commerce-database "./src/Foundation/Foundation.csproj" -S 127.0.0.1,1433 -U sa -P yourStrongP@ssword --database-name "$commerce_db" --reuse-cms-user
echo "after create db"
#docker exec -it sql_server_optimizely /opt/mssql-tools/bin/sqlcmd -S $SQLSERVER -U SA -P $password -d $commerce_db -b -i "./build/SqlScripts/FoundationConfigurationSchema.sql" -v appname=$APPNAME
#docker exec -it sql_server_optimizely /opt/mssql-tools/bin/sqlcmd -S $SQLSERVER -U SA -P $password -d $commerce_db -b -i "./build/SqlScripts/UniqueCouponSchema.sql"

echo "Executing SQL scripts"
./sqlcmd -S $SQLSERVER -U SA -d $commerce_db -b -i "./build/SqlScripts/FoundationConfigurationSchema.sql" -v appname=$APPNAME
./sqlcmd -S $SQLSERVER -U SA -d $commerce_db -b -i "./build/SqlScripts/UniqueCouponSchema.sql"


#dotnet run --project src/Foundation/Foundation.csproj