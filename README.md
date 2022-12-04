# Terraform, Ansible and WordPress on EC2 Ubuntu

## Prerequisite
1. An Ubuntu instance with **aws_credentials** installed inside **/home/ubuntu/.aws/credentials** directory.
2. **Terraform v1.3.5**, and **Ansible 2.9.27** installed. 

### Github preparation
1. On you local machine create a directory for your WordPress site: 
```bash
mkdir wordpress && git clone https://github.com/WordPress/WordPress
```
2. Next remove `https://github.com/WordPress/WordPress.git` as the origin:
```bash
git remote rm origin
```
3. Next change Master branch to Main: 
```bash
git branch -m master main
```

4. Now go to Github and create a private repository and follow commands to "…or push an existing repository from the command line". 

5. Once you have pushed your local WordPress to the private repo, go back to Github and click your profile photo in the top right corner and select **settings > Developer settings > Personal access tokens > Fined-grained Tokens > Generate new token**. 
 - On the "New fine-grained personal access token Beta" screen select "Only select repositories" and select your private WordPress repo. 
 - For permissions select "Contents -  Repository contents, commits, branches, downloads, releases, and merges." and select "Read-only" from the selection dropdown. 
 - On the next screen copy your created token in a safe place and add it to `prod.tfvars`.

### AWS preparation
We need a domain name and an Elastic IP ready to use.
**IMPORTANT: Make sure your Elastic IP is in the same AWS region you are deploying to in prod.tfvars**
1. Go to EC2 and navigate to "**Elastic IPs**" and click "**Allocate Elastic IP address**". Make note of the **AllocatedIPv4** address and **Allocation ID**. 
2. Next go to Route 53 and navigate to "**Hosted zones**" then click "**Create hosted zone**". 
3. After creating the zone add an **'A' record** that points to the **AllocatedIPv4** from the **EC2 Elastic IP**. 
4. The last step is to go to your **domain registar/DNS provider** and create an **'A' record** that also points to the **AllocatedIPv4** from the **EC2 Elastic IP**.

### Configure Prod Vars    
Now we are going to configure our prod.tfvars. 
7. The region you wish to deploy to (must be in same region as **Elastic IP**)
1. First add your a unique DB password that will be used for the RDS instance
2. Next add the allocation_id from the EIP
3. Add Personal access token
4. Add Github username
5. Name of existing Github repo
6. An email address for Letsencrypt to use


### Let rip
We are now ready to let things rip. 
1. Ready, first run `terraform init` 
2. Aim, test things out with a `terraform plan -var-file="prod.tfvars"`
3. Fire! `terraform apply -auto-approve -var-file="prod.tfvars"`

To run with debug:
```bash
export TF_LOG="DEBUG" TF_LOG_PATH="./debug" && terraform apply -auto-approve -var-file="prod.tfvars" 
```
