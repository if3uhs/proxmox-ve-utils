<div align="center">

# proxmox-ve-kits

<img src="" height="250px" width="250px">

##### Description
  
</div>

## snippets

<details>
<summary>hk_global</summary>


```bash
flags:
  -l,--[no]log       echo 'log' >> /var/run/vimd.log (default: false)
  -p,--poll          detect vm running interval(s) (default: 5)
```
  
#### Usage
  
```bash
flag:                 -l or --log                 desc: When specified, enable log writing      default: false
param:                -p or --poll                desc: Detect vm running interval(s)           default: 5(s)
```
  
`add the following to the vm description:`  
```bash
+ hk_global -l -p 10
```  
</details>


<details>
<summary>hk_pfbridge</summary>
  
#### Usage
  
```bash
positiona1:                 netX                        desc: vmconf option                           default:
positiona2:                 nicX                        desc: nic                                     default:
```
  
`add the following to the vm description:`  
```bash
+ hk_pfbridge net0 enp1s0
```  
  
</details>
