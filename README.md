# FinGuard: Secure Financial Transaction Platform (PoC)

## C4 Container Architecture (Target Production State for PCI DSS)

```mermaid
%%{init: {'theme': 'neutral'}}%%
flowchart TB
    %% External Entities
    User((Bank Client))
    VPN((Corporate VPN))

    subgraph AWS_Cloud [AWS Cloud]
        direction TB
        subgraph VPC [VPC - 10.0.0.0/16]
            direction TB
            IGW[Internet Gateway]
            WAF[AWS WAF / DDoS Protection]

            subgraph Public_Subnet [Public Subnet - 10.0.1.0/24]
                ALB[Application Load Balancer<br>HTTPS / TLS 1.2]
                NAT[NAT Gateway]
                Bastion[Bastion Host / Nginx Proxy]
            end

            subgraph Private_Subnet[Private Subnet - 10.0.2.0/24]
                AppServer[FinGuard App Server<br>EC2 / ECS]
            end
            
            subgraph Data_Subnet[Secure Data Subnet - 10.0.3.0/24]
                DB[(Amazon RDS<br>KMS Encrypted)]
                S3[Amazon S3<br>Transaction Logs]
            end
        end
        
        %% AWS Managed Security Services
        KMS[AWS KMS<br>Encryption Keys]
        IAM[AWS IAM<br>Strict RBAC]
        CW[CloudWatch<br>Audit & Logging]
    end

    %% Connections
    User -- "HTTPS (443)" --> WAF
    WAF -- "Filtered Traffic" --> IGW
    IGW --> ALB
    VPN -- "IPSec Tunnel" --> Bastion
    
    ALB -- "Routes to" --> AppServer
    Bastion -- "SSH Admin Access" --> AppServer
    AppServer -- "Egress Internet" --> NAT
    
    AppServer -- "Reads/Writes" --> DB
    AppServer -- "Logs to" --> S3
    AppServer -. "Fetches Keys" .-> KMS
    
    %% Styling
    classDef external fill:#f96,stroke:#333,stroke-width:2px;
    classDef aws fill:#ff9900,stroke:#232f3e,stroke-width:2px,color:black;
    classDef secure fill:#d1e0e0,stroke:#333,stroke-width:2px;
    
    class User,VPN external;
    class WAF,ALB,NAT,IGW,KMS,IAM,CW aws;
    class AppServer,DB,S3,Bastion secure;