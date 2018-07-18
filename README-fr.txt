README :
----------

full-clip-eraser.sh : 
=====================
Test : a été testé sur plusieurs postes clip
Action :
- essaie de faire un blkdiscard sur le périphérique visé
- si blkdiscard n'est pas supporté, fait un shred puis un dd
- termine par un sata secure erase

fast-clip-eraser.sh : 
===============================================
Utilise : discard_hdparm_file.py et list_home_files_to_delete.sh
Test : testé sur un poste clip sauf pour le sata secure erase
Action : 
- essaie de faire un hdparm trim-sectors sur les blocs de certains fichiers, si la commande n'est pas supportée fait un shred de ces fichiers
- fait un hdparm write-sector de ces blocs (écriture de zéros dessus)
- vérifie que les blocs ne contiennent plus que des zéros
- termine par un sata secure erase

disk_overwrite_v1.sh
========================
Ecrit une chaine pseudo-aléatoire sur toute la surface du disque puis pioche au hasard des blocks et vérifie que leur valeur correspond bien à celle de la chaine pseudoaléatoire pour leur position. Cela permet de s'assurer qu'un ssd a effectivement été bien complètement réécrit même dans le cas où son contrôleur mettrait en oeuvre des techniques de compression et d'optimisation.
