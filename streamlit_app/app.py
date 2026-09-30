"""PHK Monitoring Dashboard — pembungkus Streamlit.

Dashboard-nya tetap file HTML di static/index.html (salinan v12); Streamlit hanya
menyajikannya lewat URL. Untuk update bulanan, ganti isi folder static/ dengan
versi HTML dan file data .js yang terbaru:

    bash sync_static.sh

Jalankan lokal:  streamlit run app.py
"""
from pathlib import Path
import streamlit as st

DASHBOARD_HEIGHT = 2600  # tinggi iframe; naikkan bila ada bagian yang terpotong
INDEX = Path(__file__).parent / "static" / "index.html"

st.set_page_config(
    page_title="PHK Monitoring Dashboard",
    page_icon="📊",
    layout="wide",
    initial_sidebar_state="collapsed",
)

# hilangkan padding bawaan Streamlit supaya dashboard memakai lebar penuh
st.markdown(
    """
    <style>
      .block-container {padding: 0 !important; max-width: 100% !important;}
      header[data-testid="stHeader"] {height: 0; visibility: hidden;}
      footer {visibility: hidden;}
      iframe {border: 0;}
    </style>
    """,
    unsafe_allow_html=True,
)

if not INDEX.exists():
    st.error("static/index.html tidak ditemukan. Jalankan `bash sync_static.sh` lebih dulu.")
    st.stop()

# st.iframe pada Streamlit >= 1.60; versi lama memakai st.components.v1.iframe
_iframe = getattr(st, "iframe", None) or st.components.v1.iframe
_iframe("app/static/index.html", height=DASHBOARD_HEIGHT, scrolling=True)
