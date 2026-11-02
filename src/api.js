const url=import.meta.env.VITE_SUPABASE_URL;
const key=import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY;
export const configured=Boolean(url&&key&&!url.includes('YOUR_PROJECT')&&!key.includes('YOUR_'));
export async function request(path,{method='GET',body,token}={}){
 const r=await fetch(`${url}${path}`,{method,headers:{apikey:key,...(token?{Authorization:`Bearer ${token}`}:(key?.startsWith('eyJ')?{Authorization:`Bearer ${key}`} : {})),'Content-Type':'application/json'},...(body?{body:JSON.stringify(body)}:{})});
 const data=await r.json().catch(()=>null);
 if(!r.ok)throw new Error(data?.message||data?.error_description||'요청을 처리하지 못했습니다. 연결과 설정을 확인해 주세요.');
 return data;
}
