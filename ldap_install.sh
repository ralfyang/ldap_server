PASS=$1
domain="dc=test,dc=kr"

rootpw_file="./chrootpw.ldif"
domin_file="./chdomain.ldif"
base_domain="./basedomain.ldif"
	if [[ $PASS = "" ]];then
		echo " -- Password not found. please insert a password after the command --"
		exit 0		
	fi
## Install OpenLDAP Server.
rm -rf /etc/openldap/slapd.d
yum -y install openldap-servers openldap-clients
cp /usr/share/openldap-servers/DB_CONFIG.example /var/lib/ldap/DB_CONFIG 
chown ldap. /var/lib/ldap/DB_CONFIG 
systemctl start slapd 
systemctl enable slapd 
SHA_PASS=`slappasswd -h {SHA} -s $PASS`


## Set OpenLDAP admin password.
cat <<EOF > $rootpw_file 
dn: olcDatabase={0}config,cn=config
changetype: modify
add: olcRootPW
olcRootPW: $SHA_PASS
EOF

ldapadd -Y EXTERNAL -H ldapi:/// -f $rootpw_file

## Import basic Schemas.
ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/openldap/schema/cosine.ldif 
ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/openldap/schema/nis.ldif 
ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/openldap/schema/inetorgperson.ldif 


## Set your domain name on LDAP DB.
#SHA_PASS2=`slappasswd -s $PASS`
cat <<EOF > $domin_file
dn: olcDatabase={1}monitor,cn=config
changetype: modify
replace: olcAccess
olcAccess: {0}to * by dn.base="gidNumber=0+uidNumber=0,cn=peercred,cn=external,cn=auth"
  read by dn.base="cn=Manager,$domain" read by * none

dn: olcDatabase={2}hdb,cn=config
changetype: modify
replace: olcSuffix
olcSuffix: $domain

dn: olcDatabase={2}hdb,cn=config
changetype: modify
replace: olcRootDN
olcRootDN: cn=Manager,$domain

dn: olcDatabase={2}hdb,cn=config
changetype: modify
add: olcRootPW
olcRootPW: $SHA_PASS

dn: olcDatabase={2}hdb,cn=config
changetype: modify
add: olcAccess
olcAccess: {0}to attrs=userPassword,shadowLastChange by
  dn="cn=Manager,$domain" write by anonymous auth by self write by * none
olcAccess: {1}to dn.base="" by * read
olcAccess: {2}to * by dn="cn=Manager,$domain" write by * read
EOF

ldapmodify -Y EXTERNAL -H ldapi:/// -f $domin_file

cat <<EOF > $base_domain
dn: $domin
objectClass: top
objectClass: dcObject
objectclass: organization
o: Server World
dc: Srv

dn: cn=Manager,$domin
objectClass: organizationalRole
cn: Manager
description: Directory Manager

dn: ou=People,$domin
objectClass: organizationalUnit
ou: People

dn: ou=Group,$domin
objectClass: organizationalUnit
ou: Group
EOF

ldapadd -x -D cn=Manager,$domain -W -f $base_domain

rm -f $rootpw_file $domin_file $base_domain
