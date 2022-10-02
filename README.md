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
  
Add the following to the vm description:  
```bash
+ hk_global -l -p 10
```  
  
</details>
