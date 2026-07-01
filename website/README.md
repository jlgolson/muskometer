# muskometer.org

Static landing page for the Muskometer macOS app. Host it wherever `muskometer.org` lives — no Cloudflare required.

## Files

- `index.html` — landing page
- `styles.css` — styles
- `favicon.png` — app icon

## Point your domain

At your registrar/DNS host, pick any static host and add records:

**GitHub Pages (free)**  
1. Push `website/` to a `muskometer` repo.  
2. Settings → Pages → deploy from `main` / root or `/docs`.  
3. Add custom domain `muskometer.org`.  
4. Registrar: `A` records to GitHub IPs, or `CNAME` `www` → `youruser.github.io`.

**Netlify / Vercel (free)**  
Drag-drop the `website` folder or connect the repo; add `muskometer.org` as custom domain; follow their DNS wizard.

**Any web host**  
Upload the three files to public HTML. Point `muskometer.org` A/CNAME to that host.

The macOS app already links to `https://muskometer.org` — once DNS propagates, popover and Settings links work.