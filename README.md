<div align="center">

# proxmox-ve-kits

<img src="" height="250px" width="250px">

##### Description
  
</div>

## snippets

<details>
<summary>hk_global</summary>
  
#### Usage
  
```bash
flag:                 -l or --log                 desc: When specified, enable log writing      default: false
param:                -p or --poll                desc: Detect vm running interval(s)           default: 5(s)
```
  
`add the following to the vm description`:  
```bash
+ hk_global -l -p 10
```  
  
</details>


<details>
<summary>hk_pfbridge</summary>
  
#### Usage
  
```bash
arg1:                 netX                        desc: vmconf option                           default:
arg2:                 nicX                        desc: nic                                     default:
```
  
`add the following to the vm description`:  
```bash
+ hk_pfbridge net0 enp1s0
```  
  
</details>
