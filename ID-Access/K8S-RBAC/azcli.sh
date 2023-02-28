# 1.Prerequisite
#   1.1 get aks-id
    AKS_ID=$(az aks show \    --resource-group myResourceGroup \    --name myAKSCluster \    --query id -o tsv)
#   1.2 two user group (Dev/Sre group)
#       Get existing Az Group ID
        app_grp_id=$(az ad group show --group CK-AppDev --query objectId -o tsv)
        sre_grp_id=$(az ad group show --group CK-AppDev --query objectId -o tsv)
#       Create new Group_ID: appdev / sre
        APPDEV_ID=$(az ad group create --display-name appdev --mail-nickname appdev --query objectId -o tsv)
        OPSSRE_ID=$(az ad group create --display-name sredev --mail-nickname opssre --query objectId -o tsv)
#   1.3 Two Users
#       New user
        echo "Please enter the UPN for application developers: " && read AAD_DEV_UPN
        echo "Please enter the secure password for application developers: " && read AAD_DEV_PW
        AKSDEV_ID=$(az ad user create  --display-name "AKS Dev"  --user-principal-name $AAD_DEV_UPN \
                    --password $AAD_DEV_PW  --query objectId -o tsv)
        # Get user id
#   1.3 Assign user in one group
        az ad group member add --group appdev --member-id $AKSDEV_ID

# 2. grant aks access to group
    az role assignment create \  --assignee $APPDEV_ID \  --role "Azure Kubernetes Service Cluster User Role" \  --scope $AKS_ID
    az role assignment create \  --assignee $OPSSRE_ID \  --role "Azure Kubernetes Service Cluster User Role" \  --scope $AKS_ID

# 3. create aks resouces for appdev / 
#    login with    
#    Devs 
        3.1 create a namespace - dev      
#       3.2 create a role - full permission in ns-dev
                role-dev-namespace.yaml
#       3.3 create a RoleBinding - role + subject(devgroup)
                rolebinding-dev-namespace.yaml 
#    Sres 
        3.1 create a namespace - dev      
#       3.2 create a role - full permission in ns-dev
        role-sre-namespace.yaml
#       3.3 create a RoleBinding - role + subject(devgroup)
        rolebinding-sre-namespace.yaml
# 4. Testing - Interact with cluster resources using AAD
#    4.1 authenticated using AAD to connect aks
        az aks get-credentials --resource-group myResourceGroup --name myAKSCluster --overwrite-existing        
#    4.2 testing dev rbac
#       in ns - dev
        kubectl run nginx-dev --image=mcr.microsoft.com/oss/nginx/nginx:1.15.5-alpine -n dev
        kubectl get all -n dev
#       out ns - dev :  ERROR
        kubectl run nginx-sre --image=mcr.microsoft.com/oss/nginx/nginx:1.15.5-alpine -n dev
        kubectl get all -n -all
#    4.3 testing sre rbac
#       in ns - dev