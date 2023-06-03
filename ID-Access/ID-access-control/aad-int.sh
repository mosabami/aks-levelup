#   az account set -s 
#   kubectl scale --replicasets/rs deployment nnnn
# 0. Scenarios:
#  - 3 users:    admin user/owner;  
#                user01 - group: ck-opssre 
                 user02 - group: ck-appdev
# 1. Create an AKS-managed Azure AD cluster,  Without AAD integration !!
#   - *** by default "Local Account Access Enabled"
#     New !!!  Public preview: Create AKS clusters without local user accounts
#      https://azure.microsoft.com/en-us/updates/public-preview-create-aks-clusters-without-local-user-accounts-2/#:~:text=Azure%20Kubernetes%20Service%20%28AKS%29%20now%20allows%20for%20Azure,reasons%20as%20anyone%20can%20use%20a%20local%20account.

#   -  Without AAD integration
    # Create an Azure resource group
    az group create --name myResourceGroup --location centralus
    az aks create -g myResourceGroup -n myManagedCluster
#  
#   1.1 user01/02:  only have sub read but no aks permission 
#       outcome: both user can NOT have kubectl get all -A
#       Why? user need to have mimum aks permission -  "AKS Cluster User Role"
#    
#  **  Setup:  Use Azure RBAC for Kubernetes Authorization    
#         use Azure Portal or  --enable-azure-rbac
#       
#      https://learn.microsoft.com/en-us/azure/aks/manage-azure-rbac
# 
#   1.2 user01: grant "AKS Cluster User Role"
#       user02: NO  "AKS Cluster User Role"
#       outcome: user01 can "have kubectl get all -A", 
#                user02 can NOT
# -------------------------------------------------------------------------
# 2. AAD Iintegration   
#  2.1 Enable  AAD integration
    --enable-aad --aad-admin-group-object-ids <id>
#   Create an AKS cluster with Azure AD enabled
    az aks create -g myResourceGroup -n myManagedCluster --enable-aad --aad-admin-group-object-ids <id> [--aad-tenant-id <id>]
#   or
#   Enable AKS-managed Azure AD Integration on existing cluster
    az aks update -g myResourceGroup -n myManagedCluster --enable-aad --aad-admin-group-object-ids <id> [--aad-tenant-id <id>]
#   check in Azure portal aks cluster configuration
#    
#  2.2 Check Access an Azure AD enabled cluster
        kubectl get nodes
    # user1: Yes
    # ueer2: No
    # reason: user02 is not in the group

-----------------------------------------------------------------------------------------
# 3  !!! BackDoor !!!: "steal" Admin credential
#
#   if give user02 have "AKS Cluster Admin Role"  {Get Managed Cluster AccessProfile by List Credential}
#   user option "--admin/-a" -- "Get cluster administrator credentials. Default: cluster user credentials."
    az aks get-credentials --resource-group myResourceGroup --name myManagedCluster --admin
#   reason:  bypassing the normal Azure AD group authentication !!!

----------------------------------------------------------------------------------------
# 4. Disable local accounts ---disable-local-accounts
#   4.1 Create a new cluster WITHOUT local or 
#       Disable local accounts on an existing cluster
    az aks create -g <resource-group> -n <cluster-name> --enable-aad --aad-admin-group-object-ids <aad-group-id> --disable-local-accounts   4.2 Disable local accounts on an existing cluster
    az aks update -g <resource-group> -n <cluster-name> --disable-local-accounts
#   note: you can also re-enable local accounts on an existing cluster
    az aks update -g <resource-group> -n <cluster-name> --enable-local
----------------------------------------------------------------------------------------
# 5. BEST Practice !! 
#    5.1 Use Conditional Access with Azure AD and AKS   
#
# https://learn.microsoft.com/en-us/azure/aks/managed-aad#use-conditional-access-with-azure-ad-and-aks
#
#    5.2 Configure just-in-time cluster access with Azure AD and AKS
#
# https://learn.microsoft.com/en-us/azure/aks/managed-aad#configure-just-in-time-cluster-access-with-azure-ad-and-aks

